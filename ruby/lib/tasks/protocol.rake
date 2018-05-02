module ProtocolTest
  class Worker
    def initialize(group_uuid:)
      @group_uuid     = group_uuid
      @counter        = 0
    end

    def do_work(protocol:)
      @counter += 1
      puts "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.instance_desc} #{protocol.am_boss? ? '*' : ' '} #{@counter % 10} working away as usual..."
    end

    def do_boss(protocol:)
      puts "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.instance_desc}   doing boss stuff..."
    end

    def do_end(protocol:)
      puts "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.instance_desc}   end block..."
      return false
    end

    def do_dead_record(protocol:, record:)
      puts "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.instance_desc}   cleaning up record #{record.instance_uuid}"
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
                              worker.do_work(protocol: protocol)
                            },
      min_boss_interval:    boss_interval,
      boss_block:           lambda { |protocol:|
                              worker.do_boss(protocol: protocol)
                            },
      min_end_interval:     end_interval,
      end_block:            lambda { |protocol:|
                              worker.do_end(protocol: protocol)
                            },
      group_uuid:           group_uuid,
      group_desc:           'some group desc',
      instance_uuid:        SecureRandom.uuid.to_s,
      instance_desc:        ENV['ID'] || "%05d" % Kernel.rand(1000),
      dead_record_timeout:  5.seconds,
      dead_record_block:    lambda { |protocol:, record:|
                              worker.do_dead_record(protocol: protocol, record: record)
                            },
      reference_time:       Chronic.parse('Jan 1, 2000 12:00:00pm'),
      timing_modulo:        timing_modulo,
      timing_offset:        timing_offset,
    )

    puts "#{Time.now.utc.iso8601(6)} #{Process.pid} starting protocol..."
    protocol.run
  end
end
