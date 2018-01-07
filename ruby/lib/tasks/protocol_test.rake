module ProtocolTest
  class Worker
    def initialize
      @counter = 0
    end

    def do_work(protocol:)
      @counter += 1
      # Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} #{@counter % 10} working away as usual..."
      puts "#{Time.now.utc.iso8601(6)} #{Process.pid} working away as usual..."
    end

    def do_boss(protocol:)
      # Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}]   doing boss stuff..."
      puts "#{Time.now.utc.iso8601(6)} #{Process.pid} doing boss stuff..."
      # sleep(0.05)
    end

    def do_end(protocol:)
      puts "#{Time.now.utc.iso8601(6)} #{Process.pid} running end block..."
      false
    end
  end
end

namespace :protocol do
  desc "Sanity check of Protocol features"
  task :test, [:group_uuid, :instance_desc, :timing_modulo, :timing_offset, :boss_interval, :end_interval, :work_interval] => :environment do |t, args|
    group_uuid    = args[:group_uuid]
    instance_desc = args[:instance_desc]
    timing_modulo = (args[:timing_modulo] || '1.0').to_f.seconds
    timing_offset = (args[:timing_offset] || '0.0').to_f.seconds
    boss_interval = (args[:boss_interval] || '5.0').to_f.seconds
    end_interval  = (args[:end_interval]  || '0.5').to_f.seconds
    work_interval = (args[:work_interval] || '1.0').to_f.seconds

    worker = ProtocolTest::Worker.new

    protocol = Protocol.new(
      group_uuid:          group_uuid,
      instance_uuid:       SecureRandom.uuid.to_s,
      instance_desc:       instance_desc,
      min_work_interval:   work_interval,
      min_boss_interval:   boss_interval,
      min_end_interval:    end_interval,
      timing_modulo:       timing_modulo,
      timing_offset:       timing_offset,
      dead_record_timeout: 10.0.seconds,
      reference_time:      Chronic.parse('Jan 1, 2010 13:00:00'),
      work_block: lambda { |protocol:|
                    worker.do_work(protocol: protocol)
                  },
      boss_block: lambda { |protocol:|
                    worker.do_boss(protocol: protocol)
                  },
      end_block:  lambda { |protocol:|
                    worker.do_end(protocol: protocol)
                  },
    )

    protocol.run
  end
end
