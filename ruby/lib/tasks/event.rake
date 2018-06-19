module DefinitelyNotBundlerUtils
  def self.record_events(course_events:)
    CourseEvent.import(
      course_events,
      on_duplicate_key_ignore: true,
    )
  end

  def self.bundle_events(instance_modulo:,
                         instance_count:,
                         max_bundle_size:,
                         max_bundle_events:)
    ##
    ## Lock the buckets handled by this worker.
    ##

    bucket_lo = (Rational(100) / instance_count * instance_modulo).floor
    bucket_hi = (Rational(100) / instance_count * (instance_modulo+1)).floor - 1

    sql_find_and_lock_bundle_buckets = %Q{
      SELECT 1 FROM bundle_buckets
      WHERE bucket_num BETWEEN #{bucket_lo} AND #{bucket_hi}
      ORDER BY bucket_num
      FOR UPDATE
    }.gsub(/\n\s*/, ' ')

    ActiveRecord::Base.connection.execute(sql_find_and_lock_bundle_buckets)

    ##
    ## Find relavent events that are bundle-able.
    ##

    sql_find_course_uuids_needing_attention = %Q{
      SELECT DISTINCT course_uuid FROM course_events
      WHERE event_uuid IN
      ( SELECT xx.event_uuid FROM
        ( SELECT yy.created_at,yy.event_uuid,bcbs.bucket_num FROM
          ( SELECT * FROM course_events
            WHERE bundle_uuid IS NULL
          ) AS yy
          INNER JOIN
          bundle_course_states as bces
          ON  yy.course_uuid   = bces.course_uuid
          AND yy.course_seqnum = bces.last_bundled_seqnum + 1
          INNER JOIN
          bundle_course_buckets as bcbs
          ON yy.course_uuid = bcbs.course_uuid
        ) AS xx
        WHERE xx.bucket_num BETWEEN #{bucket_lo} AND #{bucket_hi}
        ORDER BY xx.created_at ASC
        LIMIT 50
      )
    }.gsub(/\n\s*/, ' ')

    puts "QUERY 1: #{sql_find_course_uuids_needing_attention}"

    course_uuids_needing_attention = CourseEvent.find_by_sql(sql_find_course_uuids_needing_attention).map{|row| row['course_uuid']}
    return if course_uuids_needing_attention.none?

    course_uuid_values = course_uuids_needing_attention.map{|uuid| "'#{uuid}'"}.join(',')

    sql_find_course_events_needing_attention = %Q{
      SELECT * FROM course_events
      WHERE event_uuid IN
      ( SELECT xx.event_uuid FROM
        ( ( SELECT * FROM course_events
            WHERE bundle_uuid IS NULL
            AND   course_uuid IN ( #{course_uuid_values} )
          ) AS yy
          INNER JOIN
          bundle_course_states as bces
          ON  yy.course_uuid   = bces.course_uuid
          AND yy.course_seqnum BETWEEN bces.last_bundled_seqnum + 1 AND bces.last_bundled_seqnum + 10
        ) AS xx
      )
      ORDER BY event_uuid
      FOR UPDATE
    }.gsub(/\n\s*/, ' ')

    # puts "QUERY 2: #{sql_find_course_events_needing_attention}"

    course_events_needing_attention = CourseEvent.find_by_sql(sql_find_course_events_needing_attention)


    events_by_course_uuid = course_events_needing_attention.sort_by{ |event|
                                                              [event.course_uuid, event.course_seqnum]
                                                            }.group_by{ |event|
                                                              event.course_uuid
                                                            }

    events_by_course_uuid.map do |course_uuid, course_events|
      index = course_events.map(&:course_seqnum)
                           .each_cons(2)
                           .find_index{|cons| cons[1] - cons[0] != 1}
      unless index.nil?
        course_events[0..-1] = course_events.slice(0,1+index)
      end
    end

    puts "#{course_events_needing_attention.count} events need attention in buckets #{bucket_lo} - #{bucket_hi}"

    sql_find_and_lock_bundle_course_states = %Q{
      SELECT * FROM bundle_course_states
      WHERE course_uuid IN ( #{course_uuid_values} )
      ORDER BY course_uuid ASC
      FOR UPDATE
    }.gsub(/\n\s*/, ' ')

    bundle_course_states = BundleCourseState.find_by_sql(sql_find_and_lock_bundle_course_states)

    bundle_course_states.each do |state|
      state.last_bundled_seqnum += events_by_course_uuid[state.course_uuid].count
    end

    sql_find_and_lock_course_bundles = %Q{
      SELECT * FROM course_bundles
      WHERE is_open = TRUE
      AND course_uuid IN ( #{course_uuid_values} )
      ORDER BY uuid ASC
      FOR UPDATE
    }.gsub(/\n\s*/, ' ')

    existing_course_bundles = CourseBundle.find_by_sql(sql_find_and_lock_course_bundles)
    bundle_by_course_uuid = existing_course_bundles.inject({}){ |result, bundle|
      result[bundle.course_uuid] = bundle
      result
    }

    course_bundles_to_create = []
    bundle_entries_to_create = []

    events_by_course_uuid.each do |target_course_uuid, target_course_events|
      target_course_events.each do |target_course_event|
        target_course_uuid = target_course_event.course_uuid
        target_event_size  = Event::event_data_by_type[target_course_event.event_type.to_sym][:size]

        if bundle_by_course_uuid[target_course_uuid] &&
           ( (bundle_by_course_uuid[target_course_uuid].size + target_event_size > max_bundle_size) ||
             (bundle_by_course_uuid[target_course_uuid].course_event_seqnum_hi - bundle_by_course_uuid[target_course_uuid].course_event_seqnum_lo + 1 >= max_bundle_events) )
          bundle_by_course_uuid[target_course_uuid].is_open = false
          bundle_by_course_uuid[target_course_uuid]         = nil
        end

        if bundle_by_course_uuid[target_course_uuid].nil?
          puts "#{Time.now.utc.iso8601(6)}      adding to new bundle"
          bundle_by_course_uuid[target_course_uuid] = CourseBundle.new(
            uuid:                   SecureRandom.uuid.to_s,
            course_uuid:            target_course_event.course_uuid,
            course_event_seqnum_lo: target_course_event.course_seqnum,
            course_event_seqnum_hi: target_course_event.course_seqnum,
            size:                   target_event_size,
            is_open:                true,
            has_been_processed:     false,
            waiting_since:          Time.now,
          )
          course_bundles_to_create << bundle_by_course_uuid[target_course_uuid]
        else
          bundle_by_course_uuid[target_course_uuid].course_event_seqnum_hi  = target_course_event.course_seqnum
          bundle_by_course_uuid[target_course_uuid].size                   += target_event_size
        end

        target_course_event.bundle_uuid = bundle_by_course_uuid[target_course_uuid].uuid

        if ( (bundle_by_course_uuid[target_course_uuid].size >= max_bundle_size) ||
             (bundle_by_course_uuid[target_course_uuid].course_event_seqnum_hi - bundle_by_course_uuid[target_course_uuid].course_event_seqnum_lo + 1 >= max_bundle_events) )
          bundle_by_course_uuid[target_course_uuid].is_open = false
        end

        bundle_by_course_uuid[target_course_uuid].has_been_processed = false
        bundle_by_course_uuid[target_course_uuid].waiting_since      = Time.now
      end
    end

    if course_events_needing_attention.any?
      CourseEvent.import(
        course_events_needing_attention,
        on_duplicate_key_update: {
          conflict_target:  [:event_uuid],
          columns:          CourseEvent.column_names - ['updated_at', 'created_at']
        }
      )

      BundleCourseState.import(
        bundle_course_states.to_a,
        on_duplicate_key_update: {
          conflict_target:  [:course_uuid],
          columns:          BundleCourseState.column_names - ['updated_at', 'created_at']
        }
      )

      CourseBundle.import(
        existing_course_bundles + course_bundles_to_create,
        on_duplicate_key_update: {
          conflict_target: [:uuid],
          columns:         CourseBundle.column_names - ['updated_at', 'created_at']
        }
      )
    end
  end

  def self.confirm_events(confirmations: [])
    fetch_course_states = FetchCourseState.where(course_uuid: confirmations.keys().sort)
                                          .order(course_uuid: :asc)
                                          .lock
                                          .to_a

    fetch_course_states.each do |fetch_course_state|
      new_last_confirmed_course_seqnum = confirmations[fetch_course_state.course_uuid]
      if new_last_confirmed_course_seqnum > fetch_course_state.last_confirmed_course_seqnum
        fetch_course_state.last_confirmed_course_seqnum = new_last_confirmed_course_seqnum
      end
    end

    if fetch_course_states.any?
      FetchCourseState.import(
        fetch_course_states,
        on_duplicate_key_update: {
          conflict_target: [:client_uuid, :course_uuid],
          columns:         FetchCourseState.column_names - ['updated_at', 'created_at']
        }
      )
    end
  end

  def self.fetch_events(instance_modulo:,
                        instance_count:,
                        client_uuid:)
    ##
    ## Lock the buckets handled by this worker.
    ##

    bucket_lo = (Rational(100) / instance_count * instance_modulo).floor
    bucket_hi = (Rational(100) / instance_count * (instance_modulo+1)).floor - 1

    sql_find_and_lock_fetch_buckets = %Q{
      SELECT 1 FROM fetch_buckets
      WHERE bucket_num BETWEEN #{bucket_lo} AND #{bucket_hi}
      ORDER BY bucket_num
      FOR UPDATE
    }.gsub(/\n\s*/, ' ')

    ActiveRecord::Base.connection.execute(sql_find_and_lock_fetch_buckets)

    ##
    ## Find courses with new events for this client.
    ##

    sql_find_course_uuids_needing_attention = %Q{
      SELECT t2.course_uuid FROM
      ( SELECT * FROM
        ( SELECT fcss.course_uuid,fcss.last_confirmed_course_seqnum,fcss.waiting_since,fcbs.bucket_num FROM
          fetch_course_states AS fcss
          INNER JOIN fetch_course_buckets AS fcbs
          ON fcss.course_uuid = fcbs.course_uuid
          WHERE fcss.client_uuid = '#{client_uuid}'
        ) AS t1
        WHERE t1.bucket_num BETWEEN #{bucket_lo} AND #{bucket_hi}
      ) AS t2
      INNER JOIN bundle_course_states AS bcss
      ON t2.course_uuid = bcss.course_uuid
      WHERE t2.last_confirmed_course_seqnum < bcss.last_bundled_seqnum
      ORDER BY waiting_since ASC
      LIMIT 50
    }.gsub(/\n\s*/, ' ')

    puts "QUERY 1: #{sql_find_course_uuids_needing_attention}"

    course_uuids_needing_attention = ActiveRecord::Base.connection.execute(sql_find_course_uuids_needing_attention).map{|row| row['course_uuid']}
    return [] if course_uuids_needing_attention.none?

    course_uuid_values = course_uuids_needing_attention.map{|uuid| "'#{uuid}'"}.join(',')

    ##
    ## Find the CourseEvents needing attention from this client.
    ##

    sql_find_course_events_needing_attention = %Q{
      SELECT * FROM course_events
      WHERE event_uuid IN
      ( SELECT t2.event_uuid FROM
        ( SELECT fcss.course_uuid,fcss.last_confirmed_course_seqnum,bcss.last_bundled_seqnum
          FROM fetch_course_states AS fcss
          INNER JOIN bundle_course_states AS bcss
          ON fcss.course_uuid = bcss.course_uuid
          WHERE fcss.client_uuid = '#{client_uuid}'
          AND   fcss.course_uuid IN ( #{course_uuid_values} )
          AND   fcss.last_confirmed_course_seqnum < bcss.last_bundled_seqnum
        ) AS t1
        INNER JOIN LATERAL
        ( SELECT *
          FROM course_events AS ces
          WHERE ces.course_uuid = t1.course_uuid
          AND   ces.course_seqnum BETWEEN t1.last_confirmed_course_seqnum + 1
                                  AND LEAST(t1.last_confirmed_course_seqnum + 10, t1.last_bundled_seqnum)
          LIMIT 10
        ) AS t2
        ON TRUE
      )
    }.gsub(/\n\s*/, ' ')

    puts "QUERY 2: #{sql_find_course_events_needing_attention}"

    course_events_needing_attention = CourseEvent.find_by_sql(sql_find_course_events_needing_attention)

    return course_events_needing_attention
  end
end

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

      ##
      ## Pull a random set of course uuids from the db.
      ##

      sql_find_random_course_uuids = %Q{
        SELECT course_uuid FROM temp_course_event_metadata
        ORDER BY random()
        LIMIT #{num_courses}
      }.gsub(/\n\s*/, ' ')

      rows = ActiveRecord::Base.connection.execute(sql_find_random_course_uuids)
      fail "unable to load desired number of course uuids from database (actual != expected) (#{rows.count} != #{num_courses})" \
        if rows.count != num_courses

      @course_uuids = rows.map{|row| row['course_uuid']}

      ##
      ## Determine the cutoffs used when determining event types.
      ##

      freqs          = Event::event_types.map{|type| Event::event_data_by_type[type][:freq]}
      freq_sum       = freqs.inject(&:+)
      freq_cumsums   = freqs.inject([]){|result, freq| result << (result.last || 0) + freq; result}
      @event_cutoffs = freq_cumsums.map{|value| value/freq_sum}
    end

    def do_work(protocol:)
      Rails.logger.level = :info
      # Rails.logger.level = :debug

      @counter += 1
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.am_boss? ? '*' : ' '} #{@counter % 10} working away as usual..."

      start = Time.now

      course_events = CourseEvent.transaction(isolation: :read_committed) do
        ##
        ## Determine which courses will have new events, and lock
        ## the associated TempCourseEventMetadata rows.
        ##

        event_course_uuids       = @course_uuids.sample(@events_per_interval)
        event_course_uuid_values = event_course_uuids.map{|uuid| "'#{uuid}'"}.join(',')

        sql_find_and_lock_temp_course_event_metadatas = %Q{
          SELECT * FROM temp_course_event_metadata
          WHERE course_uuid in ( #{event_course_uuid_values} )
          ORDER BY course_uuid ASC
          FOR UPDATE
        }.gsub(/\n\s*/, ' ')

        temp_course_event_metadatas = TempCourseEventMetadata.find_by_sql(sql_find_and_lock_temp_course_event_metadatas)

        course_events = temp_course_event_metadatas.map{ |temp_course_event_metadata|
          course_uuid = temp_course_event_metadata.course_uuid

          seqnum = 1 + temp_course_event_metadata.last_created_course_seqnum

          rand_value = Kernel::rand()
          event_type = Event::event_types[@event_cutoffs.each_index.detect{|ii| @event_cutoffs[ii] >= rand_value}]

          CourseEvent.new(
            course_uuid:        course_uuid,
            course_seqnum:      seqnum,
            event_type:         event_type,
            event_uuid:         SecureRandom.uuid.to_s,
            event_time:         Time.now,
          )
        }

        temp_course_event_metadatas.each do |tcem|
          tcem.last_created_course_seqnum += 1
        end

        # CourseEvent.import course_events
        DefinitelyNotBundlerUtils.record_events(course_events: course_events)

        TempCourseEventMetadata.import(
          temp_course_event_metadatas,
          on_duplicate_key_update: {
            conflict_target:  [:course_uuid],
            columns:          TempCourseEventMetadata.column_names - ['updated_at', 'created_at']
          }
        )

        course_events
      end

      elapsed = Time.now - start
      Rails.logger.info "   create wrote #{course_events.size} events in #{'%1.3e' % elapsed} sec"
      puts "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.am_boss? ? '*' : ' '} #{@counter % 10} created #{course_events.size} events in #{'%1.3e' % elapsed} sec"
    end

    def do_boss(protocol:)
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}]   doing boss stuff..."
      # sleep(0.05)
    end
  end

  class BundleWorker
    def initialize(group_uuid:)
      @group_uuid = group_uuid

      @max_bundle_size   = 50_000
      @max_bundle_events = 100

      @counter = 0
    end

    def do_work(protocol:)
      # Rails.logger.level = :info unless protocol.modulo == 0
      Rails.logger.level = :debug

      @counter += 1
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.am_boss? ? '*' : ' '} #{@counter % 10} working away as usual..."

      start = Time.now

      puts "#{Time.now.utc.iso8601(6)} start of transaction"
      course_events_size = CourseEvent.transaction(isolation: :read_committed) do
        DefinitelyNotBundlerUtils.bundle_events(
          instance_modulo:   protocol.modulo,
          instance_count:    protocol.count,
          max_bundle_size:   @max_bundle_size,
          max_bundle_events: @max_bundle_events,
        )
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
    def initialize(group_uuid:, client_name:)
      @group_uuid  = group_uuid
      @client_name = client_name

      @client_uuid   = nil
      @confirmations = {}

      @counter = 0
    end

    def do_work(protocol:)
      Rails.logger.level = :info unless protocol.modulo == 0

      ##
      ## If @client_uuid has not been set, try to set it.
      ##

      unless @client_uuid
        ActiveRecord::Base.connection.transaction(isolation: :read_committed) do
          sql_find_clients = %Q{
            SELECT * FROM fetch_course_clients
            WHERE client_name = '#{@client_name}'
            LIMIT 1
          }.gsub(/\n\s*/, ' ')

          client = FetchCourseClient.find_by_sql(sql_find_clients).first
          return if client.nil?

          @client_uuid = client.client_uuid
        end
      end

      @counter += 1
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.am_boss? ? '*' : ' '} #{@counter % 10} working away as usual..."

      start = Time.now

      CourseEvent.transaction(isolation: :read_committed) do
        DefinitelyNotBundlerUtils.confirm_events(confirmations: @confirmations)
      end

      events = CourseEvent.transaction(isolation: :read_committed) do
        events = DefinitelyNotBundlerUtils.fetch_events(
          instance_modulo: protocol.modulo,
          instance_count:  protocol.count,
          client_uuid:     @client_uuid,
        )

        events
      end

      events_by_course_uuid = events.group_by{ |event|
        event.course_uuid
      }

      @confirmations = events_by_course_uuid.inject({}) { |result, (course_uuid, events)|
        result[course_uuid] = events.sort_by{|event| event.course_seqnum}.last.course_seqnum
        result
      }

      elapsed = Time.now - start

      puts "#{Time.now.utc.iso8601(6)} processed #{events.count} events in elapsed = #{'%1.3e' % elapsed} sec"
      Rails.logger.info "   fetch wrote #{events.count} events in elapsed = #{'%1.3e' % elapsed} sec"
    end

    def do_boss(protocol:)
      # Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}]   doing boss stuff..."

      # start = Time.now

      # ##
      # ## Add an entry to the course stream's client table, if needed.
      # ##

      # unless @client_uuid
      #   client = ActiveRecord::Base.connection.transaction(isolation: :read_committed) do
      #     sql_find_clients = %Q{
      #       SELECT * FROM course_clients
      #       WHERE name = '#{@client_name}'
      #     }.gsub(/\n\s*/, ' ')

      #     client = CourseClient.find_by_sql(sql_find_clients).first
      #     if client.nil?
      #       client = CourseClient.new(
      #         uuid: SecureRandom.uuid.to_s,
      #         name: @client_name,
      #       )
      #       client.save!
      #     end

      #     client
      #   end

      #   @client_uuid = client.uuid
      # end

      # ##
      # ## Create client states for any missing courses.
      # ##

      # puts "#{Time.now.utc.iso8601(6)} starting course check transaction"
      # ActiveRecord::Base.connection.transaction(isolation: :read_committed) do
      #   sql_find_course_event_states = %Q{
      #     SELECT * FROM course_event_states
      #     WHERE course_uuid NOT IN (
      #       SELECT course_uuid FROM course_client_states
      #       WHERE client_uuid = '#{@client_uuid}'
      #     )
      #   }.gsub(/\n\s*/, ' ')

      #   course_event_states = CourseEventState.find_by_sql(sql_find_course_event_states)

      #   puts "adding #{course_event_states.count} course client states"

      #   current_time = Time.now

      #   client_states = course_event_states.map{ |client_state|
      #     CourseClientState.new(
      #       client_uuid:                  @client_uuid,
      #       course_uuid:                  client_state.course_uuid,
      #       last_confirmed_course_seqnum: -1,
      #       needs_attention:              true,
      #       waiting_since:                current_time,
      #     )
      #   }

      #   CourseClientState.import client_states
      # end
      # elapsed = Time.now - start
      # puts "#{Time.now.utc.iso8601(6)} finished course check transaction elapsed = #{'%1.3e' % elapsed}"
    end
  end

end

namespace :event do
  desc 'create courses'
  task :create_courses, [:num_courses] => :environment do |t, args|
    num_courses = (args[:num_courses] || '1').to_i

    start = Time.now

    course_uuids = num_courses.times.map{ SecureRandom.uuid.to_s }

    bundle_course_buckets = course_uuids.map{ |course_uuid|
      BundleCourseBucket.new(
        course_uuid: course_uuid,
        bucket_num:  Kernel.rand(100),
      )
    }

    bundle_course_states = course_uuids.map{ |course_uuid|
      BundleCourseState.new(
        course_uuid:          course_uuid,
        last_bundled_seqnum:  -1,
      )
    }

    fetch_course_buckets = course_uuids.map{ |course_uuid|
      FetchCourseBucket.new(
        course_uuid: course_uuid,
        bucket_num:  Kernel.rand(100),
      )
    }

    temp_course_event_metadatas = course_uuids.map{ |course_uuid|
      TempCourseEventMetadata.new(
        course_uuid:                course_uuid,
        last_created_course_seqnum: -1,
      )
    }

    BundleCourseBucket.transaction(isolation: :read_committed) do
      BundleCourseBucket.import bundle_course_buckets
      BundleCourseState.import  bundle_course_states

      FetchCourseBucket.import fetch_course_buckets

      TempCourseEventMetadata.import temp_course_event_metadatas
    end

    elapsed = Time.now - start

    puts "created #{num_courses} courses in #{elapsed} sec"
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
      min_update_interval: 1.second,
      timing_modulo:       work_modulo,
      timing_offset:       work_offset,
      group_uuid:          group_uuid,
      group_desc:          'creators',
      instance_uuid:       SecureRandom.uuid.to_s,
      instance_desc:       Process.pid.to_s,
      work_block:          lambda { |protocol:| worker.do_work(protocol: protocol) },
      boss_block:          lambda { |protocol:| worker.do_boss(protocol: protocol) },
      reference_time:      Chronic.parse('Jan 1, 2000 12:00:00.001pm'),
      dead_record_timeout: 10.seconds,
    )

    protocol.run
  end
end

namespace :event do
  desc 'bundle course events into per-course streams'
  task :bundle, [:group_uuid, :work_interval, :work_modulo, :work_offset] => :environment do |t, args|
    group_uuid          = args[:group_uuid]
    work_interval       = (args[:work_interval]       || '1.0').to_f.seconds
    boss_interval       = Rails.env.production? ? 30.seconds : 5.seconds
    work_modulo         = (args[:work_modulo]         || '1.0').to_f.seconds
    work_offset         = (args[:work_offset]         || '0.0').to_f.seconds

    worker = Event::BundleWorker.new(
      group_uuid: group_uuid,
    )

    protocol = Protocol.new(
      min_work_interval:   work_interval,
      min_boss_interval:   boss_interval,
      min_update_interval: 1.second,
      timing_modulo:       work_modulo,
      timing_offset:       work_offset,
      group_uuid:          group_uuid,
      group_desc:          'bundlers',
      instance_uuid:       SecureRandom.uuid.to_s,
      instance_desc:       Process.pid.to_s,
      work_block:          lambda { |protocol:| worker.do_work(protocol: protocol) },
      boss_block:          lambda { |protocol:| worker.do_boss(protocol: protocol) },
      reference_time:      Chronic.parse('Jan 1, 2000 12:00:00.002 pm'),
      dead_record_timeout: 10.seconds,
    )

    protocol.run
  end
end

namespace :event do
  desc 'create client'
  task :create_client, [:client_name] => :environment do |t, args|
    client_name = args[:client_name]
    client_uuid = SecureRandom.uuid.to_s

    course_client = FetchCourseClient.transaction(isolation: :read_committed) do
      course_client = FetchCourseClient.new(
        client_name: client_name,
        client_uuid: client_uuid,
      )

      FetchCourseClient.import(
        [course_client],
        on_duplicate_key_ignore: true
      )

      course_client = FetchCourseClient.where(client_name: client_name).first

      course_client
    end

    if course_client.client_uuid == client_uuid
      puts "  created client #{client_name} with client_uuid #{course_client.client_uuid}"
    else
      puts "  client #{client_name} already existed with client_uuid #{course_client.client_uuid}"
    end
  end
end

namespace :event do
  desc 'update clients'
  task :update_clients => :environment do |t, args|
    FetchCourseState.transaction(isolation: :read_committed) do
      ##
      ## Find
      ##

      sql_find_missing_course_and_client_uuids = %Q{
        SELECT t1.course_uuid,t1.client_uuid FROM
        ( SELECT * FROM fetch_course_buckets,fetch_course_clients ) AS t1
        FULL OUTER JOIN
        fetch_course_states AS fcss
        ON  t1.course_uuid = fcss.course_uuid
        AND t1.client_uuid = fcss.client_uuid
        WHERE fcss.course_uuid IS NULL
        LIMIT 10000
      }.gsub(/\n\s*/, ' ')

      course_client_uuid_pairs = ActiveRecord::Base.connection.execute(sql_find_missing_course_and_client_uuids).map{|row| [row['course_uuid'], row['client_uuid']]}
      puts "updating #{course_client_uuid_pairs.count} course/clients pairs"
      break if course_client_uuid_pairs.none?

      ##
      ## Create
      ##

      fetch_client_states = course_client_uuid_pairs.map{ |course_uuid,client_uuid|
        FetchCourseState.new(
          course_uuid:                  course_uuid,
          client_uuid:                  client_uuid,
          last_confirmed_course_seqnum: -1,
          needs_attention:              false,
          waiting_since:                Time.now.utc,
        )
      }

      FetchCourseState.import(
        fetch_client_states,
        on_duplicate_key_ignore: true,
      )
    end
  end
end

namespace :event do
  desc 'fetch events'
  task :fetch, [:group_uuid, :work_interval, :work_modulo, :work_offset, :client_name] => :environment do |t, args|
    group_uuid          = args[:group_uuid]
    work_interval       = (args[:work_interval]       || '1.0').to_f.seconds
    boss_interval       = 1.0.seconds #Rails.env.production? ? 30.seconds : 5.seconds
    work_modulo         = (args[:work_modulo]         || '1.0').to_f.seconds
    work_offset         = (args[:work_offset]         || '0.0').to_f.seconds
    client_name         = args[:client_name]

    worker = Event::FetchWorker.new(
      group_uuid:   group_uuid,
      client_name:  client_name,
    )

    protocol = Protocol.new(
      min_work_interval:   work_interval,
      min_boss_interval:   boss_interval,
      min_update_interval: 1.second,
      timing_modulo:       work_modulo,
      timing_offset:       work_offset,
      group_uuid:          group_uuid,
      group_desc:          'fetchers',
      instance_uuid:       SecureRandom.uuid.to_s,
      instance_desc:       Process.pid.to_s,
      work_block:          lambda { |protocol:| worker.do_work(protocol: protocol) },
      boss_block:          lambda { |protocol:| worker.do_boss(protocol: protocol) },
      reference_time:      Chronic.parse('Jan 1, 2000 12:00:00.003 pm'),
      dead_record_timeout: 10.seconds,
    )

    protocol.run
  end
end
