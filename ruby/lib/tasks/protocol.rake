class Worker
  def initialize(group_uuid:)
    @group_uuid     = group_uuid
    @counter        = 0
  end

  def do_work(count:, modulo:, am_boss:)
    @counter += 1
    Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} #{@counter % 10} working away as usual..."

    start = Time.now

    num_records = 100
    # uuids = num_records.times.map{ SecureRandom.uuid.to_s }
    # ActiveRecord::Base.connection_pool.with_connection do
      # ExperRecord.transaction(isolation: :serializable) do
      ExperRecord.transaction(isolation: :repeatable_read) do
        num_records.times.map do
          ExperRecord.create!(
            uuid:  SecureRandom.uuid,
            uuid1: SecureRandom.uuid,
            uuid2: SecureRandom.uuid,
            uuid3: SecureRandom.uuid,
            uuid4: SecureRandom.uuid,
            uuid5: SecureRandom.uuid,
            uuid6: SecureRandom.uuid,
            uuid7: SecureRandom.uuid,
            uuid8: SecureRandom.uuid,
            uuid9: SecureRandom.uuid,
          )
        end
        # uuids.map{|uuid| ExperRecord.create!(uuid: uuid)}
        # exper_records.map(&:save!)
      end
    # end

    elapsed = Time.now - start
    Rails.logger.info "   wrote #{num_records} records in #{'%1.3e' % elapsed} sec"
  end

  def do_boss(count:, modulo:)
    Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}]   doing boss stuff..."
    # sleep(0.05)
  end
end

namespace :protocol do
  desc "Join the 'exper' protocol group"
  task :exper, [:group_uuid, :work_interval, :work_modulo, :work_offset] => :environment do |t, args|
    group_uuid    = args[:group_uuid]
    work_interval = (args[:work_interval] || '1.0').to_f.seconds
    boss_interval = 5.seconds
    work_modulo   = (args[:work_modulo]   || '1.0').to_f.seconds
    work_offset   = (args[:work_offset]   || '0.0').to_f.seconds

    worker = Worker.new(group_uuid: group_uuid)

    protocol = Protocol.new(
      protocol_name: 'exper',
      min_work_interval: work_interval,
      min_boss_interval: boss_interval,
      work_modulo: work_modulo,
      work_offset: work_offset,
      group_uuid: group_uuid,
      work_block: lambda { |instance_count:, instance_modulo:, am_boss:|
                    worker.do_work(count: instance_count, modulo: instance_modulo, am_boss: am_boss)
                  },
      boss_block: lambda { |instance_count:, instance_modulo:|
                    worker.do_boss(count: instance_count, modulo: instance_modulo)
                  }
    )

    protocol.run
  end
end
