 class Protocol
  class Helpers
    def self.compute_next_time(current_time:,
                               reference_time:,
                               timing_modulo:,
                               timing_offset:,
                               instance_count:,
                               instance_modulo:,
                               interval:)
      modulo_time        = reference_time - (reference_time.to_f % timing_modulo)
      interval_base_time = modulo_time + timing_offset + (instance_modulo.to_f/instance_count)*interval
      next_time          = interval_base_time + (((current_time - interval_base_time)/interval).floor + 1)*interval
      next_time
    end

    def self.read_group_records(group_uuid:)
      group_records = ActiveRecord::Base.connection_pool.with_connection do
        ProtocolRecord.where(group_uuid: group_uuid).to_a
      end
      group_records
    end

    def self.categorize_records(instance_uuid:, dead_record_timeout:, group_records:)
      instance_record = group_records.detect{|rec| rec.instance_uuid == instance_uuid}
      live_records    = group_records.select{|rec| rec.updated_at > Time.now - dead_record_timeout}
      dead_records    = group_records - live_records

      [instance_record, live_records, dead_records]
    end

    def self.get_boss_situation(instance_uuid:, live_records:)
      ## Quickly deal with the no-record case.
      return [false, nil] if live_records.empty?

      ##
      ## Group the live records by their vote for boss_uuid.
      ##

      uuid, votes = live_records.group_by(&:boss_uuid)
                                .inject([]){|result, (uuid, records)|
                                   result << [uuid, records.count]
                                   result
                                }.sort_by{|uuid, count| count}
                                .last

      ##
      ## In order for a boss to be elected:
      ##   - the boss must have a strict majority of votes (no ties allowed!)
      ##   - the boss must be in the live record set (no dead bosses allowed!)
      ##

      boss_uuid   = (votes > live_records.count/2.0) ? uuid : nil
      boss_record = live_records.detect{|rec| rec.instance_uuid == boss_uuid}
      boss_uuid   = nil unless boss_record

      ##
      ## Determine if the target instance is the boss.
      ##

      am_boss = (boss_uuid == instance_uuid)

      [am_boss, boss_record]
    end

    def self.create_record(group_uuid:, instance_uuid:, instance_desc:)
      ##
      ## There is some extra looping to protect against
      ## the possibility of accidentally violating the
      ## uniqueness constraint on [:group_uuid, :instance_modulo],
      ## which should only happen very, very rarely.
      ##

      record = loop do
        retries ||= 0

        begin
          modulo = -1000 - rand(1_000)

          record = ActiveRecord::Base.connection_pool.with_connection do
            ProtocolRecord.create!(
              group_uuid:          group_uuid,
              instance_uuid:       instance_uuid,
              instance_count:      1,
              instance_modulo:     modulo,
              instance_desc:       instance_desc,
              boss_uuid:           instance_uuid,
              next_end_time:       Time.now.utc,
              next_boss_time:      Time.now.utc,
              next_work_time:      Time.now.utc,
              next_wake_time:      Time.now.utc,
            )
          end

          break record
        rescue ActiveRecord::WrappedDatabaseException
          retry if (retries += 1) < 20
          raise "failed after #{retries} retries"
        end
      end

      record
    end

    def self.save_record(record:)
      ActiveRecord::Base.connection_pool.with_connection do
        record.updated_at = Time.now
        record.save!
      end
    end

    def self.update_boss_vote(instance_record:, live_records:)
      if live_records.any?
        lowest_uuid = live_records.map(&:instance_uuid).sort.first
        instance_record.boss_uuid      = lowest_uuid
        instance_record.instance_count = live_records.count
      else
        instance_record.boss_uuid      = instance_record.instance_uuid
        instance_record.instance_count = 1
      end
      self.save_record(record: instance_record)
    end

    def self.allocate_modulo(instance_record:, live_records:, boss_record:)
      actual_modulos = live_records.map(&:instance_modulo).sort
      target_modulos = (0..boss_record.instance_count-1).to_a
      if actual_modulos != target_modulos
        if (instance_record.instance_modulo < 0) || (instance_record.instance_modulo >= boss_record.instance_count)
          boss_instance_count = boss_record.instance_count

          all_modulos = (0..boss_instance_count-1).to_a
          taken_modulos = live_records.select{ |rec|
            (rec.instance_modulo >= 0) && (rec.instance_modulo < boss_instance_count)
          }.map(&:instance_modulo).sort

          available_modulos = all_modulos - taken_modulos
          success = false
          available_modulos.each do |target_modulo|
            begin
              instance_record.instance_modulo = target_modulo
              instance_record.instance_count  = live_records.count
              save_record(record: instance_record)
              success = true
              break
            rescue ActiveRecord::WrappedDatabaseException
              ##
              ## It's possible that another instance took the target modulo
              ## before this instance could get it, so just swallow this
              ## exception.
              ##
            end
          end

          sleep 0.05.seconds unless success

          ##
          ## Whether or not we were able to allocate a modulo,
          ## return true to indicate that some action was taken.
          ##

          return true
        end
      end

      ##
      ## No action was taken, so return false.
      ##

      return false
    end
  end
end