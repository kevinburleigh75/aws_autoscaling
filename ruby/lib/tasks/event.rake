module Event
  class EventWorker
    def initialize(group_uuid:, events_per_interval:, num_courses:)
      @group_uuid          = group_uuid
      @events_per_interval = events_per_interval
      @num_courses         = num_courses

      @counter = 0

      @event_types    = ['Response', 'EcosystemUpdate', 'Lifecycle']
      @course_uuids   = num_courses.times.map{ SecureRandom.uuid.to_s }
      @course_seqnums = @course_uuids.inject({}) { |result, uuid|
        result[uuid] = Array(0..3)
        result
      }

      CourseState.transaction(isolation: :read_committed) do
        course_states = @course_uuids.map { |course_uuid|
          CourseState.new(
            course_uuid: course_uuid,
            is_archived: false,
          )
        }

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

        CourseEvent.new(
          course_uuid:                    course_uuid,
          course_seqnum:                  seqnum,
          event_type:                     @event_types.sample,
          event_uuid:                     SecureRandom.uuid.to_s,
          event_time:                     Time.now,
          partition_value:                Kernel.rand(1*2*3*4*5*6*7*8*9*10),
          has_been_processed_by_stream_1: false,
          has_been_processed_by_stream_2: false,
        )
      }

      CalcRequest.transaction do
        CourseEvent.import course_events
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

      @counter = 0
    end

    def do_work(count:, modulo:, am_boss:)
      Rails.logger.level = :info

      @counter += 1
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} #{@counter % 10} working away as usual..."

      start = Time.now

      events_size = CourseEvent.transaction(isolation: :read_committed) do
        ##
        ## Find the N oldest unprocessed events per course of interest.
        ##

        uuid_order = ['ASC', 'DESC'].sample

        sql_find_course_events = %Q{
          SELECT * FROM course_events
          WHERE event_uuid IN (
            SELECT * FROM (
              SELECT event_uuid FROM (
                SELECT DISTINCT course_uuid FROM course_states cs
                WHERE uuid_partition(cs.course_uuid) % #{count} = #{modulo}
              ) cuuids_oi
              LEFT JOIN LATERAL (
                SELECT * FROM course_events
                WHERE course_uuid = cuuids_oi.course_uuid
                AND has_been_processed_by_stream_#{@stream_id} = FALSE
                ORDER BY course_uuid, course_seqnum ASC
                LIMIT 10
              ) oces ON TRUE
              ORDER BY oces.course_uuid #{uuid_order}, oces.course_seqnum ASC
              LIMIT 100
            ) euuids
            ORDER BY event_uuid ASC
          )
          FOR UPDATE
        }.gsub(/\n\s*/, ' ')

        # puts sql_find_course_events
        course_events = CourseEvent.find_by_sql(sql_find_course_events)
        puts course_events.size
        # puts "#{course_events.map(&:event_uuid).sort}"

        ##
        ## Create/update bundles and create bundle entries
        ##

        # bools = course_events.map{|event| event.send("has_been_processed_by_stream_#{@stream_id}".to_sym)}
        # puts "B: #{bools}"

        course_events.each do |course_event|
          course_event.send("has_been_processed_by_stream_#{@stream_id}=".to_sym, true)
        end

        # bools = course_events.map{|event| event.send("has_been_processed_by_stream_#{@stream_id}".to_sym)}
        # puts "A: #{bools}"

        ##
        ## Write everything to the db.
        ##

        course_events.map(&:save!)

        course_events.size
      end

      elapsed = Time.now - start
      Rails.logger.info "   wrote #{events_size} events in #{'%1.3e' % elapsed} sec"
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