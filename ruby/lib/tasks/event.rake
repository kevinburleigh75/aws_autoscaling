module Event
  @@event_data_by_type = {
    'Response': {
      size:   1_000,
      freq: 100_000.0,
    },
    'EcosystemUpdate': {
      size: 1_000_000,
      freq:         1.0,
    },
    'Lifecycle': {
      size:    50,
      freq:     1.0,
    },
  }

  @@event_types = @@event_data_by_type.keys.sort

  def self.event_data_by_type
    @@event_data_by_type
  end

  def self.event_types
    @@event_types
  end

  class EventWorker
    def initialize(group_uuid:, events_per_interval:, num_courses:)
      @group_uuid          = group_uuid
      @events_per_interval = events_per_interval
      @num_courses         = num_courses

      @counter = 0

      @course_uuids   = num_courses.times.map{ SecureRandom.uuid.to_s }
      @course_seqnums = @course_uuids.inject({}) { |result, uuid|
        result[uuid] = Array(0..0)
        result
      }

      freqs          = Event::event_types.map{|type| Event::event_data_by_type[type][:freq]}
      freq_sum       = freqs.inject(&:+)
      freq_cumsums   = freqs.inject([]){|result, freq| result << (result.last || 0) + freq; result}
      @event_cutoffs = freq_cumsums.map{|value| value/freq_sum}

      course_event_states = @course_uuids.map { |course_uuid|
        CourseEventState.new(
          course_uuid:        course_uuid,
          last_course_seqnum: -1,
          needs_attention:    false,
          waiting_since:      Time.now,
        )
      }

      CourseEventState.transaction(isolation: :read_committed) do
        CourseEventState.import course_event_states
      end

      course_bundle_states = @course_uuids.map { |course_uuid|
        Stream1CourseBundleState.new(
          course_uuid:        course_uuid,
          needs_attention:    false,
          waiting_since:      Time.now,
        )
      }

      Stream1CourseBundleState.transaction(isolation: :read_committed) do
        Stream1CourseBundleState.import course_bundle_states
      end
    end

    def do_work(protocol:)
      Rails.logger.level = :info

      @counter += 1
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.am_boss? ? '*' : ' '} #{@counter % 10} working away as usual..."

      start = Time.now

      course_events = @events_per_interval.times.map{
        course_uuid = @course_uuids.sample

        seqnum         = @course_seqnums[course_uuid].sample
        new_max_seqnum = 1 + @course_seqnums[course_uuid].max

        @course_seqnums[course_uuid].delete(seqnum)
        @course_seqnums[course_uuid] << new_max_seqnum

        rand_value = Kernel::rand()
        event_type = Event::event_types[@event_cutoffs.each_index.detect{|ii| @event_cutoffs[ii] >= rand_value}]

        # puts "%s %1.3f %s" % [@event_cutoffs.map{|ec| "%1.3f" % ec}.join(','), rand_value, event_type]

        CourseEvent.new(
          course_uuid:                    course_uuid,
          course_seqnum:                  seqnum,
          event_type:                     event_type,
          event_uuid:                     SecureRandom.uuid.to_s,
          event_time:                     Time.now,
          partition_value:                Kernel.rand(1*2*3*4*5*6*7*8*9*10),
          has_been_processed_by_stream1:  false,
          has_been_processed_by_stream2:  false,
        )
      }

      course_uuids       = course_events.map(&:course_uuid).uniq.sort
      course_uuid_values = course_uuids.map{|uuid| "'#{uuid}'"}.join(',')

      seqnums_by_course_uuid = course_events.inject({}) { |result, event|
        result[event.course_uuid] = {} unless result.has_key?(event.course_uuid)
        result[event.course_uuid][event.course_seqnum] = true
        result
      }

      CourseEventState.transaction(isolation: :read_committed) do
        ##
        ## Import the course events.
        ##

        CourseEvent.import course_events

        ##
        ## Find and lock the associated course states.
        ##

        sql_find_and_lock_course_event_states = %Q{
          SELECT * FROM course_event_states
          WHERE course_uuid IN ( #{course_uuid_values} )
          ORDER BY course_uuid ASC
          FOR UPDATE
        }.gsub(/\n\s*/, ' ')

        course_event_states = CourseEventState.find_by_sql(sql_find_and_lock_course_event_states)

        ##
        ## Update and save the course states
        ##

        states_to_update = course_event_states.select{ |state|
          seqnums_by_course_uuid[state.course_uuid].has_key?(1 + state.last_course_seqnum)
        }.each{ |state|
          state.needs_attention = true
          state.waiting_since   = Time.now
        }

        CourseEventState.import(
          states_to_update,
          on_duplicate_key_update: {
            conflict_target: [:course_uuid],
            columns: CourseEventState.column_names - ['updated_at', 'created_at']
          }
        )
      end

      elapsed = Time.now - start
      Rails.logger.info "   create wrote #{course_events.size} events in #{'%1.3e' % elapsed} sec"
    end

    def do_boss(protocol:)
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}]   doing boss stuff..."
      # sleep(0.05)
    end
  end

  class BundleWorker
    def initialize(group_uuid:, stream_id:)
      @group_uuid = group_uuid
      @stream_id  = stream_id

      @max_bundle_size   = 50_000
      @max_bunele_events = 100

      @counter           = 0
    end

    def do_work(protocol:)
      Rails.logger.level = :info unless protocol.modulo == 0

      @counter += 1
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.am_boss? ? '*' : ' '} #{@counter % 10} working away as usual..."

      start = Time.now

      puts "#{Time.now.utc.iso8601(6)} start of transaction"
      course_events_size = CourseEvent.transaction(isolation: :read_committed) do
        ##
        ## Find the courses that need attention and have been waiting the longest.
        ##

        sql_find_and_lock_course_event_states = %Q{
          SELECT * FROM course_event_states
          WHERE course_uuid IN (
            SELECT course_uuid FROM course_event_states
            WHERE needs_attention = TRUE
            AND   uuid_partition(course_uuid) % #{protocol.count} = #{protocol.modulo}
            ORDER BY waiting_since ASC
            LIMIT 50
          )
          ORDER BY course_uuid ASC
          FOR UPDATE
        }.gsub(/\n\s*/, ' ')

        course_event_states = CourseEventState.find_by_sql(sql_find_and_lock_course_event_states)
        puts "#{Time.now.utc.iso8601(6)} #{course_event_states.count} courses need attention (modulo = #{protocol.modulo})"
        next 0 if course_event_states.none?

        ##
        ## Find the relevant events for the target courses.
        ##

        course_uuids       = course_event_states.map(&:course_uuid).uniq.sort
        course_uuid_values = course_uuids.map{|uuid| "'#{uuid}'"}.join(',')

        max_events_per_course = 2

        sql_find_and_lock_course_events = %Q{
          SELECT * FROM course_events
          WHERE course_events.event_uuid IN (
            SELECT xx.event_uuid FROM (
              SELECT * FROM course_event_states
              WHERE course_uuid IN ( #{course_uuid_values} )
            ) courses_oi
            LEFT JOIN LATERAL (
              SELECT * FROM course_events
              WHERE course_uuid = courses_oi.course_uuid
              AND has_been_processed_by_stream#{@stream_id} = FALSE
              ORDER BY course_uuid, course_seqnum ASC
              LIMIT #{max_events_per_course}
            ) xx ON TRUE
          )
          ORDER BY event_uuid ASC
          FOR UPDATE
        }.gsub(/\n\s*/, ' ')

        course_events = CourseEvent.find_by_sql(sql_find_and_lock_course_events)
        puts "#{Time.now.utc.iso8601(6)} #{course_events.size} events found"
        course_events.each{ |event|
          puts "    course #{event.course_uuid} event #{event.event_uuid} seqnum #{event.course_seqnum}"
        }

        ##
        ## Find and lock the course bundle states for the target courses.
        ##

        sql_find_and_lock_bundle_states = %Q{
          SELECT * FROM stream1_course_bundle_states
          WHERE course_uuid IN ( #{course_uuid_values} )
          ORDER BY course_uuid
          FOR UPDATE
        }.gsub(/\n\s*/, ' ')

        bundle_states = Stream1CourseBundleState.find_by_sql(sql_find_and_lock_bundle_states)

        ##
        ## Find and lock the client states for the target courses.
        ##

        sql_find_and_lock_stream_client_states = %Q{
          SELECT * FROM stream1_client_states
          WHERE course_uuid IN ( #{course_uuid_values} )
          ORDER BY course_uuid, client_uuid ASC
          FOR UPDATE
        }.gsub(/\n\s*/, ' ')

        client_states = Stream1ClientState.find_by_sql(sql_find_and_lock_stream_client_states)

        ##
        ## Find the currently open bundles for the target stream.
        ##

        sql_find_and_lock_stream_bundles = %Q{
          SELECT * FROM stream#{@stream_id}_bundles
          WHERE is_open = TRUE
          AND course_uuid IN ( #{course_uuid_values} )
          ORDER BY uuid ASC
          FOR UPDATE
        }.gsub(/\n\s*/, ' ')

        existing_stream_bundles = Stream1Bundle.find_by_sql(sql_find_and_lock_stream_bundles)

        ##
        ## Process the course events, grouped by course
        ##

        bundles_to_create           = []
        bundle_entries_to_create    = []
        events_to_update            = []

        activity_by_course_uuid = course_event_states.inject({}){ |result, event_state|
          result[event_state.course_uuid] = {
            activity:               false,
            num_events_added:       0,
            gap_found:              false,
            new_last_course_seqnum: -1,
          }
          result
        }

        course_events.group_by{|event| event.course_uuid}.each do |target_course_uuid, target_course_events|
          puts "#{Time.now.utc.iso8601(6)}  processing course #{target_course_uuid}"

          target_course_events = target_course_events.sort_by{|event| event.course_seqnum}

          puts "#{Time.now.utc.iso8601(6)}    #{target_course_events.count} course events:"
          target_course_events.each{|ee| puts "#{Time.now.utc.iso8601(6)}      event #{ee.event_uuid} seqnum #{ee.course_seqnum}"}

          target_course_event_state = course_event_states.detect{|es| es.course_uuid == target_course_uuid}
          target_course_open_bundle = existing_stream_bundles.detect{|bb| bb.course_uuid == target_course_uuid}
          gap_found                 = false
          new_last_course_seqnum    = target_course_event_state.last_course_seqnum

          target_course_events.each do |event|
            puts "#{Time.now.utc.iso8601(6)}    processing event #{event.event_uuid} seqnum #{event.course_seqnum}"

            ##
            ## If the event causes a gap, stop processing events for the target course.
            ##

            if event.course_seqnum != new_last_course_seqnum + 1
              puts "#{Time.now.utc.iso8601(6)}      gap found"
              gap_found = true
              activity_by_course_uuid[target_course_uuid][:gap_found] = true
              break
            end

            event.has_been_processed_by_stream1 = true
            events_to_update << event

            activity_by_course_uuid[target_course_uuid][:activity]          = true
            activity_by_course_uuid[target_course_uuid][:num_events_added] += 1

            ##
            ## Add the event to the currently open bundle, if possible.
            ## If not, close the old bundle and/or create a new bundle for it.
            ##

            new_last_course_seqnum += 1

            event_size = Event::event_data_by_type[event.event_type.to_sym][:size]

            if target_course_open_bundle &&
               ( (target_course_open_bundle.size + event_size > @max_bundle_size) ||
                 (target_course_open_bundle.course_event_seqnum_hi - target_course_open_bundle.course_event_seqnum_lo + 1 >= @max_bunele_events) )
              target_course_open_bundle.is_open = false
              target_course_open_bundle         = nil
            end

            if target_course_open_bundle.nil?
              puts "#{Time.now.utc.iso8601(6)}      adding to new bundle"
              target_course_open_bundle = Stream1Bundle.new(
                uuid:                   SecureRandom.uuid.to_s,
                course_uuid:            event.course_uuid,
                course_event_seqnum_lo: event.course_seqnum,
                course_event_seqnum_hi: event.course_seqnum,
                size:                   event_size,
                is_open:                true,
                has_been_processed:     false,
                waiting_since:          Time.now,
              )
              bundles_to_create << target_course_open_bundle
            else
              puts "#{Time.now.utc.iso8601(6)}      adding to existing bundle"
              target_course_open_bundle.course_event_seqnum_hi  = event.course_seqnum
              target_course_open_bundle.size                   += event_size
            end

            if ( (target_course_open_bundle.size >= @max_bundle_size) ||
                 (target_course_open_bundle.course_event_seqnum_hi - target_course_open_bundle.course_event_seqnum_lo + 1 >= @max_bunele_events) )
              target_course_open_bundle.is_open = false
            end

            target_course_open_bundle.has_been_processed = false
            target_course_open_bundle.waiting_since      = Time.now

            ##
            ## Create a bundle entry for this event/stream combo.
            ##

            bundle_entries_to_create << Stream1BundleEntry.new(
              course_event_uuid:  event.event_uuid,
              stream_bundle_uuid: target_course_open_bundle.uuid,
            )

            ##
            ## Update the course bundle state.
            ##

            target_bundle_state = bundle_states.detect{|bs| bs.course_uuid == target_course_uuid}

            if !target_bundle_state.needs_attention
              target_bundle_state.needs_attention = true
              target_bundle_state.waiting_since   = Time.now
            end
          end ## end of per-event processing

          activity_by_course_uuid[target_course_uuid][:new_last_course_seqnum] = new_last_course_seqnum
        end ## end of per-course processing

        ##
        ## Update the course event and client states.
        ##

        course_event_states.each do |event_state|
          target_course_uuid = event_state.course_uuid

          puts "#{Time.now.utc.iso8601(6)}  updating event states for course #{target_course_uuid}"

          if activity_by_course_uuid[target_course_uuid][:num_events_added] < max_events_per_course
            puts "#{Time.now.utc.iso8601(6)}    course events do not need further attention"
            event_state.needs_attention = false
          else
            puts "#{Time.now.utc.iso8601(6)}    course events need further attention"
          end

          puts "#{Time.now.utc.iso8601(6)}  updating client states for course #{target_course_uuid}"

          if activity_by_course_uuid[target_course_uuid][:activity]
            event_state.last_course_seqnum = activity_by_course_uuid[target_course_uuid][:new_last_course_seqnum]
            event_state.waiting_since      = Time.now

            puts "#{Time.now.utc.iso8601(6)}    there was course activity"

            target_client_states = client_states.select{|cs| cs.course_uuid == target_course_uuid}
            puts "#{Time.now.utc.iso8601(6)}      #{target_client_states.count} clients found"

            target_client_states.each do |client_state|
              if !client_state.needs_attention
                puts "#{Time.now.utc.iso8601(6)}        client #{client_state.client_uuid} now needs attention"
                client_state.needs_attention = true
                client_state.waiting_since   = Time.now
              else
                puts "#{Time.now.utc.iso8601(6)}        client #{client_state.client_uuid} already needs attention"
              end
            end
          else
            puts "#{Time.now.utc.iso8601(6)}    there was no course activity"
          end
        end

        ##
        ## Do bulk creates/updates
        ##

        Stream1BundleEntry.import bundle_entries_to_create

        Stream1Bundle.import bundles_to_create
        Stream1Bundle.import(
          existing_stream_bundles,
          on_duplicate_key_update: {
            conflict_target: [:uuid],
            columns:         Stream1Bundle.column_names - ['updated_at', 'created_at']
          }
        )


        Stream1CourseBundleState.import(
          bundle_states,
          on_duplicate_key_update: {
            conflict_target: [:course_uuid],
            columns:         Stream1CourseBundleState.column_names - ['updated_at', 'created_at']
          }
        )

        CourseEvent.import(
          course_events,
          on_duplicate_key_update: {
            conflict_target: [:event_uuid],
            columns: CourseEvent.column_names - ['updated_at', 'created_at']
          }
        )

        CourseEventState.import(
          course_event_states,
          on_duplicate_key_update: {
            conflict_target: [:course_uuid],
            columns: CourseEventState.column_names - ['updated_at', 'created_at']
          }
        )

        Stream1ClientState.import(
          client_states,
          on_duplicate_key_update: {
            conflict_target: [:client_uuid, :course_uuid],
            columns: Stream1ClientState.column_names - ['updated_at', 'created_at']
          }
        )

        course_events.size
      end

      elapsed = Time.now - start
      puts "#{Time.now.utc.iso8601(6)} end of transaction elasped = #{'%1.3e' % elapsed}"

      Rails.logger.info "   bundle processed #{course_events_size} events in #{'%1.3e' % elapsed} sec #{elapsed > 0.5 ? 'OVER' : ''}"
    end

    def do_boss(protocol:)
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}]   doing boss stuff..."
      # sleep(0.05)
    end
  end

  class FetchWorker
    def initialize(group_uuid:, stream_id:, client_name:)
      @group_uuid  = group_uuid
      @stream_id   = stream_id
      @client_name = client_name

      @counter = 0

      ##
      ## Add an entry to the stream's client table, if needed.
      ##

      client = ActiveRecord::Base.connection.transaction(isolation: :read_committed) do
        sql_find_clients = %Q{
          SELECT * FROM stream1_clients
          WHERE name = '#{@client_name}'
        }.gsub(/\n\s*/, ' ')

        client = Stream1Client.find_by_sql(sql_find_clients).first
        if client.nil?
          client = Stream1Client.new(
            uuid: SecureRandom.uuid.to_s,
            name: @client_name,
          )
          client.save!
        end

        client
      end

      @client_uuid = client.uuid

      @next_course_check_time = Time.now
    end

    def do_work(protocol:)
      Rails.logger.level = :info #unless modulo == 0

      @counter += 1
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.am_boss? ? '*' : ' '} #{@counter % 10} working away as usual..."

      start = Time.now

      if Time.now > @next_course_check_time
        puts "#{Time.now.utc.iso8601(6)} starting course check transaction"
        ActiveRecord::Base.connection.transaction(isolation: :read_committed) do
          ##
          ## Create client states for any missing courses.
          ##

          sql_find_course_event_states = %Q{
            SELECT * FROM course_event_states
            WHERE course_uuid NOT IN (
              SELECT course_uuid FROM stream1_client_states
              WHERE client_uuid = '#{@client_uuid}'
            )
            AND uuid_partition(course_uuid) % #{protocol.count} = #{protocol.modulo}
          }.gsub(/\n\s*/, ' ')

          course_event_states = CourseEventState.find_by_sql(sql_find_course_event_states)
          puts "adding #{course_event_states.count} courses for client #{@client_name} #{@client_uuid}"

          current_time = Time.now

          client_states = course_event_states.map{ |event_state|
            Stream1ClientState.new(
              client_uuid:                  @client_uuid,
              course_uuid:                  event_state.course_uuid,
              last_confirmed_course_seqnum: -1,
              needs_attention:              true,
              waiting_since:                current_time,
            )
          }

          Stream1ClientState.import client_states
        end
        elapsed = Time.now - start
        puts "#{Time.now.utc.iso8601(6)} finished course check transaction elapsed = #{'%1.3e' % elapsed}"

        @next_course_check_time += (2.5 + 5*Kernel.rand).seconds
      end

      puts "#{Time.now.utc.iso8601(6)} starting transaction"
      num_processed_events = ActiveRecord::Base.connection.transaction(isolation: :read_committed) do
        current_time = Time.now

        ##
        ## Find and lock the client states needing attention.
        ##

        sql_find_and_lock_stream_client_states = %Q{
          SELECT * FROM stream#{@stream_id}_client_states
          WHERE course_uuid IN (
            SELECT course_uuid FROM stream#{@stream_id}_client_states
            WHERE needs_attention = TRUE
            AND   client_uuid = '#{@client_uuid}'
            AND   uuid_partition(course_uuid) % #{protocol.count} = #{protocol.modulo}
            ORDER BY waiting_since ASC
            LIMIT 10
          )
          AND client_uuid = '#{@client_uuid}'
          ORDER BY course_uuid ASC
          FOR UPDATE
        }.gsub(/\n\s*/, ' ')

        stream_client_states = Stream1ClientState.find_by_sql(sql_find_and_lock_stream_client_states)
        puts "#{Time.now.utc.iso8601(6)} #{stream_client_states.count} courses need attention from client #{@client_name} #{protocol.modulo} #{@client_uuid}"
        next 0 if stream_client_states.none?

        stream_client_states.each{|state| puts "#{Time.now.utc.iso8601(6)}   #{state.course_uuid} #{state.waiting_since.iso8601(6)}"}

        ##
        ## For each state (course) of interest, find the next bundle for this client.
        ##

        course_uuids       = stream_client_states.map(&:course_uuid).sort
        course_uuid_values = course_uuids.map{|uuid| "'#{uuid}'"}.join(',')

        sql_find_stream_bundles = %Q{
          SELECT * FROM stream#{@stream_id}_bundles
          WHERE uuid IN (
            SELECT xx.uuid FROM (
              SELECT * FROM stream#{@stream_id}_client_states
              WHERE course_uuid IN ( #{course_uuid_values} )
              AND   client_uuid = '#{@client_uuid}'
            ) client_states_oi
            LEFT JOIN LATERAL (
              SELECT * FROM stream#{@stream_id}_bundles
              WHERE course_uuid = client_states_oi.course_uuid
              AND course_event_seqnum_hi > client_states_oi.last_confirmed_course_seqnum
              ORDER BY course_event_seqnum_hi ASC
              LIMIT 2
            ) xx ON TRUE
          )
        }.gsub(/\n\s*/, ' ')

        stream_bundles = Stream1Bundle.find_by_sql(sql_find_stream_bundles)
        puts "#{Time.now.utc.iso8601(6)} found #{stream_bundles.count} bundles for client #{@client_name} #{@client_uuid}"

        num_processed_events = 0
        if stream_bundles.any?
          ##
          ## Find the events associated with the bundles.
          ##

          bundle_uuids       = stream_bundles.map(&:uuid).sort
          bundle_uuid_values = bundle_uuids.map{|uuid| "'#{uuid}'"}.join(',')

          sql_find_course_events = %Q{
            SELECT * FROM course_events
            WHERE event_uuid IN (
              SELECT course_event_uuid FROM stream#{@stream_id}_bundle_entries
              WHERE stream_bundle_uuid in ( #{bundle_uuid_values} )
            )
          }.gsub(/\n\s*/, ' ')

          course_events = CourseEvent.find_by_sql(sql_find_course_events)
                                     .select{ |event|
                                       last_confirmed_course_seqnum = stream_client_states.detect{|state| state.course_uuid == event.course_uuid}.last_confirmed_course_seqnum
                                       event.course_seqnum > last_confirmed_course_seqnum
                                      }

          puts "#{Time.now.utc.iso8601(6)} found #{course_events.count} course events"

          now = Time.now

          course_events.group_by{ |event|
            event.course_uuid
          }.each{ |course_uuid, events|
            puts "events for course #{course_uuid}:"
            events.each{|ee| puts "  #{ee.event_uuid} #{ee.course_seqnum} #{ee.created_at.iso8601(6)} #{now.iso8601(6)} #{now - ee.created_at}"}
          }

          delays = course_events.group_by{ |event|
            event.course_uuid
          }.map{ |course_uuid, events|
            dels = events.map(&:created_at).map{|ca| now - ca}
            [dels.min, dels.max]
          }
          min_delay = delays.map{|dd| dd[0]}.min
          max_delay = delays.map{|dd| dd[1]}.max
          puts "#{Time.now.utc.iso8601(6)} min,max delay = %+1.3e,%1.3e" % [min_delay, max_delay]

          num_processed_events = course_events.count
        end

        puts "#{Time.now.utc.iso8601(6)} finished processing stream bundles"

        ##
        ## Update client states.
        ##

        stream_client_states.each do |client_state|
          puts "#{Time.now.utc.iso8601(6)} updating client state for course #{client_state.course_uuid}"

          bundles = stream_bundles.select{|bundle| bundle.course_uuid == client_state.course_uuid}
                                  .sort_by{|bundle| bundle.course_event_seqnum_hi}

          puts "#{Time.now.utc.iso8601(6)}   #{bundles.count} bundles"

          client_state.waiting_since   = current_time
          client_state.needs_attention = (bundles.count > 1) ## FOR DEMO PURPOSES ONLY
          if bundles.any?
            puts "#{Time.now.utc.iso8601(6)}   bundles[0] course_event_seqnum_hi = #{bundles[0].course_event_seqnum_hi}"
            client_state.last_confirmed_course_seqnum = bundles[0].course_event_seqnum_hi ## FOR DEMO PURPOSES ONLY
          end
        end

        Stream1ClientState.import(
          stream_client_states,
          on_duplicate_key_update: {
            conflict_target: [:course_uuid, :client_uuid],
            columns:         Stream1ClientState.column_names - ['updated_at', 'created_at']
          }
        )

        puts "#{Time.now.utc.iso8601(6)} finished processing client states"

        num_processed_events
      end
      elapsed = Time.now - start

      puts "#{Time.now.utc.iso8601(6)} finished transaction elapsed = #{'%1.3e' % elapsed}"
      Rails.logger.info "   fetch wrote #{num_processed_events} events in #{'%1.3e' % elapsed} sec"
    end

    def do_boss(protocol:)
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}]   doing boss stuff..."
      # sleep(0.05)
    end
  end

end

namespace :event do
  desc 'create course events'
  task :create, [:group_uuid, :work_interval, :work_modulo, :work_offset, :events_per_interval, :num_courses] => :environment do |t, args|
    group_uuid          = args[:group_uuid]
    work_interval       = (args[:work_interval]       || '1.0').to_f.seconds
    boss_interval       = Rails.env.production? ? 30.seconds : 5.seconds
    work_modulo         = (args[:work_modulo]         || '1.0').to_f.seconds
    work_offset         = (args[:work_offset]         || '0.0').to_f.seconds
    events_per_interval = (args[:events_per_interval] || '1').to_i
    num_courses         = (args[:num_courses]         || '1').to_i

    worker = Event::EventWorker.new(
      group_uuid:          group_uuid,
      events_per_interval: events_per_interval,
      num_courses:         num_courses,
    )

    protocol = Protocol.new(
      min_work_interval:   work_interval,
      min_boss_interval:   boss_interval,
      timing_modulo:       work_modulo,
      timing_offset:       work_offset,
      group_uuid:          group_uuid,
      group_desc:          'creators',
      instance_uuid:       SecureRandom.uuid.to_s,
      instance_desc:       Process.pid.to_s,
      work_block:          lambda { |protocol:| worker.do_work(protocol: protocol) },
      boss_block:          lambda { |protocol:| worker.do_boss(protocol: protocol) },
      reference_time:      Chronic.parse('Jan 1, 2000 12:00pm'),
      dead_record_timeout: 10.seconds,
    )

    protocol.run
  end
end

namespace :event do
  desc 'bundle course events into per-course streams'
  task :bundle, [:group_uuid, :work_interval, :work_modulo, :work_offset, :stream_id] => :environment do |t, args|
    group_uuid          = args[:group_uuid]
    work_interval       = (args[:work_interval]       || '1.0').to_f.seconds
    boss_interval       = Rails.env.production? ? 30.seconds : 5.seconds
    work_modulo         = (args[:work_modulo]         || '1.0').to_f.seconds
    work_offset         = (args[:work_offset]         || '0.0').to_f.seconds
    stream_id           = args[:stream_id]

    worker = Event::BundleWorker.new(
      group_uuid: group_uuid,
      stream_id:  stream_id,
    )

    protocol = Protocol.new(
      min_work_interval:   work_interval,
      min_boss_interval:   boss_interval,
      timing_modulo:       work_modulo,
      timing_offset:       work_offset,
      group_uuid:          group_uuid,
      group_desc:          'bundlers',
      instance_uuid:       SecureRandom.uuid.to_s,
      instance_desc:       Process.pid.to_s,
      work_block:          lambda { |protocol:| worker.do_work(protocol: protocol) },
      boss_block:          lambda { |protocol:| worker.do_boss(protocol: protocol) },
      reference_time:      Chronic.parse('Jan 1, 2000 12:00pm'),
      dead_record_timeout: 10.seconds,
    )

    protocol.run
  end
end

namespace :event do
  desc 'fetch events'
  task :fetch, [:group_uuid, :work_interval, :work_modulo, :work_offset, :stream_id, :client_name] => :environment do |t, args|
    group_uuid          = args[:group_uuid]
    work_interval       = (args[:work_interval]       || '1.0').to_f.seconds
    boss_interval       = Rails.env.production? ? 30.seconds : 5.seconds
    work_modulo         = (args[:work_modulo]         || '1.0').to_f.seconds
    work_offset         = (args[:work_offset]         || '0.0').to_f.seconds
    stream_id           = args[:stream_id]
    client_name         = args[:client_name]

    worker = Event::FetchWorker.new(
      group_uuid:   group_uuid,
      stream_id:    stream_id,
      client_name:  client_name,
    )

    protocol = Protocol.new(
      min_work_interval:   work_interval,
      min_boss_interval:   boss_interval,
      timing_modulo:       work_modulo,
      timing_offset:       work_offset,
      group_uuid:          group_uuid,
      group_desc:          'bundlers',
      instance_uuid:       SecureRandom.uuid.to_s,
      instance_desc:       Process.pid.to_s,
      work_block:          lambda { |protocol:| worker.do_work(protocol: protocol) },
      boss_block:          lambda { |protocol:| worker.do_boss(protocol: protocol) },
      reference_time:      Chronic.parse('Jan 1, 2000 12:00pm'),
      dead_record_timeout: 10.seconds,
    )

    protocol.run
  end
end