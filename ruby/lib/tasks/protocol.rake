module ProtocolTest
  class Worker
    def initialize(group_uuid:)
      @group_uuid     = group_uuid
      @counter        = 0
    end

    def do_work(count:, modulo:, am_boss:)
      @counter += 1
      puts "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} #{@counter % 10} working away as usual..."
    end

    def do_boss(count:, modulo:, protocol:)
      puts "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}]   doing boss stuff..."
    end

    def do_end(count:, modulo:, am_boss:)
      puts "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}]   end block..."
      return false
    end
  end
end

namespace :protocol do
  desc "protcol test"
  task :test, [:group_uuid, :work_interval, :boss_interval, :end_interval, :timing_modulo, :timing_offset] => :environment do |t, args|
    group_uuid    = args[:group_uuid]
    work_interval = args[:work_interval].nil? ? nil : args[:work_interval].to_f.seconds
    boss_interval = args[:boss_interval].nil? ? nil : args[:boss_interval].to_f.seconds
    end_interval  = args[:end_interval].nil?  ? nil : args[:end_interval].to_f.seconds
    timing_modulo = (args[:timing_modulo] || '5.0').to_f.seconds
    timing_offset = (args[:timing_offset] || '0.0').to_f.seconds

    worker = ProtocolTest::Worker.new(
      group_uuid: group_uuid,
    )

    protocol = Protocol.new(
      min_work_interval:    work_interval,
      work_block:           lambda { |protocol:|
                              worker.do_work(count: protocol.count, modulo: protocol.modulo, am_boss: protocol.am_boss?)
                            },
      min_boss_interval:    boss_interval,
      boss_block:           lambda { |protocol:|
                              worker.do_boss(count: protocol.count, modulo: protocol.modulo, protocol: protocol)
                            },
      min_end_interval:     end_interval,
      end_block:            lambda { |protocol:|
                              worker.do_end(count: protocol.count, modulo: protocol.modulo, am_boss: protocol.am_boss?)
                            },
      group_uuid:           group_uuid,
      instance_uuid:        SecureRandom.uuid.to_s,
      instance_desc:        ENV['AWS_INSTANCE_ID'],
      dead_record_timeout:  5.seconds,
      reference_time:       Chronic.parse('Jan 1, 2000 12:00:00pm'),
      timing_modulo:        timing_modulo,
      timing_offset:        timing_offset,
    )

    protocol.run
  end
end
