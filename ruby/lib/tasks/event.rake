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

      course_states = @course_uuids.map { |course_uuid|
        CourseState.new(
          course_uuid:        course_uuid,
          last_course_seqnum: -1,
          needs_attention:    false,
          waiting_since:      Time.now,
        )
      }

      CourseState.transaction(isolation: :read_committed) do
        CourseState.import course_states
      end
    end

    def do_work(count:, modulo:, am_boss:)
      Rails.logger.level = :info

      @counter += 1
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} #{@counter % 10} working away as usual..."

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

      CourseState.transaction(isolation: :read_committed) do
        ##
        ## Find and lock the associated course states.
        ##

        sql_find_and_lock_course_states = %Q{
          SELECT * FROM course_states
          WHERE course_uuid IN ( #{course_uuid_values} )
          ORDER BY course_uuid ASC
          FOR UPDATE
        }.gsub(/\n\s*/, ' ')

        course_states = CourseState.find_by_sql(sql_find_and_lock_course_states)

        ##
        ## Import the course events.
        ##

        CourseEvent.import course_events

        ##
        ## Update and save the course states
        ##

        time = Time.now

        course_states.each do |state|
          if seqnums_by_course_uuid[state.course_uuid].has_key?(1 + state.last_course_seqnum)
            state.needs_attention = true
            state.waiting_since   = time
            state.save!
          end
        end
      end

      elapsed = Time.now - start
      Rails.logger.info "   wrote #{course_events.size} events in #{'%1.3e' % elapsed} sec"
    end

    def do_boss(count:, modulo:, protocol:)
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}]   doing boss stuff..."
      # sleep(0.05)
    end
  end

  class BundleWorker
    def initialize(group_uuid:, stream_id:)
      @group_uuid = group_uuid
      @stream_id  = stream_id

      @max_bundle_size = 50_000
      @counter         = 0
    end

    def do_work(count:, modulo:, am_boss:)
      Rails.logger.level = :info

      @counter += 1
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} #{@counter % 10} working away as usual..."

      start = Time.now

      course_events_size = CourseEvent.transaction(isolation: :read_committed) do
        ##
        ## Find the courses that need attention and have been waiting the longest.
        ##

        sql_find_and_lock_course_states = %Q{
          SELECT * FROM course_states
          WHERE course_uuid IN (
            SELECT course_uuid FROM course_states
            WHERE needs_attention = TRUE
            AND   uuid_partition(course_uuid) % #{count} = #{modulo}
            ORDER BY waiting_since ASC
            LIMIT 10
          )
          ORDER BY course_uuid ASC
          FOR UPDATE
        }.gsub(/\n\s*/, ' ')

        course_states = CourseState.find_by_sql(sql_find_and_lock_course_states)
        puts "#{course_states.count} courses need attention"
        next 0 if course_states.none?

        ##
        ## Find the relevant events for the target courses.
        ##

        course_uuids       = course_states.map(&:course_uuid).uniq.sort
        course_uuid_values = course_uuids.map{|uuid| "'#{uuid}'"}.join(',')

        sql_find_and_lock_course_events = %Q{
          SELECT * FROM course_events
          WHERE course_events.event_uuid IN (
            SELECT xx.event_uuid FROM (
              SELECT * FROM course_events
              WHERE course_uuid IN ( #{course_uuid_values} )
              AND has_been_processed_by_stream#{@stream_id} = FALSE
            ) events_oi
            LEFT JOIN LATERAL (
              SELECT * FROM course_events
              WHERE course_uuid = events_oi.course_uuid
              AND has_been_processed_by_stream#{@stream_id} = FALSE
              ORDER BY course_uuid, course_seqnum ASC
              LIMIT 10
            ) xx ON TRUE
          )
          ORDER BY event_uuid ASC
          FOR UPDATE
        }.gsub(/\n\s*/, ' ')

        course_events = CourseEvent.find_by_sql(sql_find_and_lock_course_events)
        puts course_events.size

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

        stream_bundles = Object.const_get("Stream#{@stream_id}Bundle").find_by_sql(sql_find_and_lock_stream_bundles)

        ##
        ## Update the course states, bundles and events
        ##

        course_states.each do |state|
          target_events = course_events.select{|event| event.course_uuid == state.course_uuid}
                                       .sort_by{|event| event.course_seqnum}

          cur_stream_open_bundle = stream_bundles.detect{|bundle| bundle.course_uuid == state.course_uuid}

          gap_found              = false
          new_last_course_seqnum = state.last_course_seqnum

          puts "  processing course #{state.course_uuid}"
          target_events.each do |event|
            puts "    course #{event.course_uuid} seqnum #{new_last_course_seqnum} event #{event.course_seqnum} #{event.event_type} #{event.event_uuid}"

            ##
            ## If the event causes a gap, stop processing events for the target course.
            ##

            if event.course_seqnum != new_last_course_seqnum + 1
              puts "      gap found"
              gap_found = true
              break
            end

            new_last_course_seqnum += 1

            ##
            ## Add the event to the currently open bundle, if possible.
            ## If not, close the old bundle and create a new bundle for it.
            ##

            event_size = Event::event_data_by_type[event.event_type.to_sym][:size]

            if cur_stream_open_bundle && (cur_stream_open_bundle.size + event_size > @max_bundle_size)
              cur_stream_open_bundle.is_open = false
              cur_stream_open_bundle.save!
              cur_stream_open_bundle = nil
            end

            if cur_stream_open_bundle.nil?
              cur_stream_open_bundle = Object.const_get("Stream#{@stream_id}Bundle").new(
                uuid:                   SecureRandom.uuid.to_s,
                course_uuid:            state.course_uuid,
                course_event_seqnum_lo: event.course_seqnum,
                course_event_seqnum_hi: event.course_seqnum,
                size:                   event_size,
                is_open:                true,
              )
            else
              cur_stream_open_bundle.course_event_seqnum_hi  = event.course_seqnum
              cur_stream_open_bundle.size                   += event_size
            end

            if cur_stream_open_bundle.size >= @max_bundle_size
              cur_stream_open_bundle.is_open = false
            end

            cur_stream_open_bundle.save!

            ##
            ## Create a bundle entry for this event/stream combo.
            ##

            Object.const_get("Stream#{@stream_id}BundleEntry").create!(
              course_event_uuid:  event.event_uuid,
              stream_bundle_uuid: cur_stream_open_bundle.uuid,
            )

            ##
            ## Update the event to show that it's been processed by the current stream.
            ##

            event.send("has_been_processed_by_stream#{@stream_id}=".to_sym, true)
            event.save!
          end

          if (target_events.count < 10) or gap_found
            puts "    course does not need further attention"
            state.needs_attention = false
          end

          state.last_course_seqnum = new_last_course_seqnum
          state.waiting_since      = Time.now

          state.save!
        end

        course_events.size
      end

      elapsed = Time.now - start
      Rails.logger.info "   wrote #{course_events_size} events in #{'%1.3e' % elapsed} sec"
    end

    def do_boss(count:, modulo:, protocol:)
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}]   doing boss stuff..."
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
      min_work_interval:  work_interval,
      min_boss_interval:  boss_interval,
      work_modulo:        work_modulo,
      work_offset:        work_offset,
      group_uuid:         group_uuid,
      work_block: lambda { |instance_count:, instance_modulo:, am_boss:|
                    worker.do_work(count: instance_count, modulo: instance_modulo, am_boss: am_boss)
                  },
      boss_block: lambda { |instance_count:, instance_modulo:, protocol:|
                    worker.do_boss(count: instance_count, modulo: instance_modulo, protocol: protocol)
                  }
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
      min_work_interval:  work_interval,
      min_boss_interval:  boss_interval,
      work_modulo:        work_modulo,
      work_offset:        work_offset,
      group_uuid:         group_uuid,
      work_block: lambda { |instance_count:, instance_modulo:, am_boss:|
                    worker.do_work(count: instance_count, modulo: instance_modulo, am_boss: am_boss)
                  },
      boss_block: lambda { |instance_count:, instance_modulo:, protocol:|
                    worker.do_boss(count: instance_count, modulo: instance_modulo, protocol: protocol)
                  }
    )

    protocol.run

  end
end

namespace :event do
  desc 'create missing client receipts'
  task :receipt, [:group_uuid, :work_interval, :work_modulo, :work_offset] => :environment do |t, args|

  end
end

namespace :event do
  desc 'fetch events'
  task :fetch, [:group_uuid, :work_interval, :work_modulo, :work_offset] => :environment do |t, args|

  end
end