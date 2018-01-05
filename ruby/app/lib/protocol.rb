class Protocol
  def initialize(min_end_interval: 1e10.seconds,
                 end_block: lambda {},
                 min_boss_interval: 1e10.seconds,
                 boss_block: lambda {},
                 min_work_interval: 1e10.seconds,
                 work_block: lambda {})
    @min_end_interval  = min_end_interval
    @end_block         = end_block
    @min_boss_interval = min_boss_interval
    @boss_block        = boss_block
    @min_work_interval = min_work_interval
    @work_block        = work_block
  end

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
      record.touch
      record.save!
    end
  end

  def self.update_boss_vote(instance_record:, live_records:)
    lowest_uuid = live_records.map(&:instance_uuid).sort.first
    instance_record.boss_uuid      = lowest_uuid
    instance_record.instance_count = live_records.count
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

        available_modulos.each do |target_modulo|
          begin
            instance_record.instance_modulo = target_modulo
            instance_record.instance_count  = live_records.count
            save_record(record: instance_record)
            break
          rescue ActiveRecord::WrappedDatabaseException
            ##
            ## It's possible that another instance took the target modulo
            ## before this instance could get it, so just swallow this
            ## exception.
            ##
          end
        end

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

  def run
    ##
    ## This is needed to ensure multi-thread applications (like some specs)
    ## work as intended.
    ##

    ActiveRecord::Base.clear_active_connections!

    ##
    ##
    ##

    current_time = Time.now
    next_end_block_time  = current_time + @min_end_interval
    next_boss_block_time = current_time + @min_boss_interval
    next_work_block_time = current_time + @min_work_interval

    loop do
      current_loop_time = Time.now

      if current_loop_time >= next_end_block_time
        next_end_block_time = current_loop_time + @min_end_interval
        break if @end_block.call
      end

      if current_loop_time >= next_boss_block_time
        @boss_block.call
        next_boss_block_time = current_loop_time + @min_boss_interval
      end

      if current_loop_time >= next_work_block_time
        @work_block.call
        next_work_block_time = current_loop_time + @min_work_interval
      end

      current_time = Time.now
      sleep [ 0,
        [
          next_end_block_time  - current_time,
          next_boss_block_time - current_time,
          next_work_block_time - current_time,
        ].min
      ].max
    end
  end
end

# class Protocol
#   attr_reader :min_work_interval
#   attr_reader :min_boss_interval
#   attr_reader :group_uuid
#   attr_reader :instance_uuid

#   def initialize(min_work_interval:,
#                  min_boss_interval:,
#                  min_end_interval:,
#                  min_update_interval:,
#                  work_modulo: 1.0.seconds,
#                  work_offset: 0.0.seconds,
#                  group_uuid:,
#                  work_block:,
#                  boss_block:,
#                  end_block:)
#     @min_work_interval   = min_work_interval
#     @min_boss_interval   = min_boss_interval
#     @min_end_interval    = min_end_interval
#     @min_update_interval = min_update_interval
#     @work_modulo         = work_modulo
#     @work_offset         = work_offset
#     @group_uuid          = group_uuid
#     @work_block          = work_block
#     @boss_block          = boss_block
#     @end_block           = end_block

#     @instance_uuid      = SecureRandom.uuid.to_s
#   end

#   def compute_next_work_time(last_time: nil, current_time:, instance_count:, instance_modulo:)
#     if last_time.nil?
#       last_time = current_time - (current_time.to_f % @work_modulo) + @work_offset + @min_work_interval/instance_count*instance_modulo
#     end

#     next_time = last_time + @min_work_interval
#   end


#   def run
#     ActiveRecord::Base.clear_active_connections!

#     # current_time = Time.now
#     next_boss_time       = nil
#     next_work_time       = nil
#     next_end_time        = Time.now
#     prev_instance_count  = nil
#     prev_instance_modulo = nil
#     # puts "current_time:   #{round_time(time: current_time).utc.iso8601(6)}"
#     # puts "next_work_time: #{round_time(time: next_work_time).utc.iso8601(6)}"

#     loop do
#       current_time = Time.now
#       if current_time >= next_end_time
#         val = @end_block.call()
#         next_end_time = current_time + @min_end_interval
#         break if val
#       end

#       my_record, group_records, dead_records = _read_records
#       unless my_record
#         puts "create!"
#         _create_record
#         next
#       end

#       am_boss, boss_record = _get_boss_situation(group_records)
#       unless boss_record
#         puts "elect!"
#         _elect_new_boss(my_record, group_records)
#         next
#       end

#       if not am_boss
#         next_boss_time = nil
#       end

#       my_record.boss_uuid      = boss_record.instance_uuid
#       my_record.instance_count = group_records.count
#       _save_record(my_record)

#       if am_boss && dead_records.any?
#         puts "destroy!"
#         dead_records.map(&:destroy)
#         next
#       end

#       actual_modulos = group_records.map(&:instance_modulo).sort
#       target_modulos = (0..boss_record.instance_count-1).to_a
#       if actual_modulos != target_modulos
#         puts "allocate needed!"
#         if (my_record.instance_modulo < 0) || (my_record.instance_modulo >= boss_record.instance_count)
#           puts "allocate myself!"
#           _allocate_modulo(my_record, group_records)
#         end
#         # sleep(0.1)
#         next
#       end

#       if (my_record.instance_modulo < 0) || (my_record.instance_modulo >= boss_record.instance_count)
#         raise "instance_modulo error (#{my_record.instance_modulo} / #{boss_record.instance_count})"
#       end

#       current_time = Time.now

#       if am_boss && (next_boss_time.nil? || current_time >= next_boss_time)
#         next_boss_time = current_time + @min_boss_interval
#         @boss_block.call(
#           instance_count:    boss_record.instance_count,
#           instance_modulo:   my_record.instance_modulo,
#           protocol:          self,
#         )
#       end

#       if next_work_time.nil? || my_record.instance_modulo != prev_instance_modulo || boss_record.instance_count != prev_instance_count
#         next_work_time = compute_next_work_time(
#           current_time:    current_time,
#           instance_count:  boss_record.instance_count,
#           instance_modulo: my_record.instance_modulo,
#         )
#         prev_instance_count  = boss_record.instance_count
#         prev_instance_modulo = my_record.instance_modulo
#       end
#       # puts "current_time:   #{round_time(time: current_time).utc.iso8601(6)}"

#       if current_time >= next_work_time
#         last_work_time = next_work_time
#         # puts "work_time:      #{round_time(time: last_work_time).utc.iso8601(6)}"
#         # puts "(am boss)" if am_boss
#         @work_block.call(
#           instance_count:  boss_record.instance_count,
#           instance_modulo: my_record.instance_modulo,
#           am_boss:         am_boss,
#         )

#         current_time = Time.now
#         next_work_time = compute_next_work_time(
#           last_time:    next_work_time,
#           current_time: current_time,
#           instance_count:  boss_record.instance_count,
#           instance_modulo: my_record.instance_modulo,
#         )
#         # puts "next_work_time: #{round_time(time: next_work_time).utc.iso8601(6)}"
#       else
#         current_time = Time.now
#         intervals = [@min_update_interval, next_work_time-current_time, next_end_time-current_time]
#         intervals << next_boss_time-current_time if am_boss
#         sleep(intervals.min)
#       end
#     end
#   rescue Interrupt => ex
#     # puts 'exiting'
#   rescue Exception => ex
#     raise ex
#   ensure
#     _destroy_record
#   end


#   def _create_record
#     # puts "create!"

#     loop do
#       retries ||= 0

#       begin
#         modulo = -1000 - rand(1_000)

#         ActiveRecord::Base.connection_pool.with_connection do
#           ProtocolRecord.create!(
#             group_uuid:          @group_uuid,
#             instance_uuid:       @instance_uuid,
#             instance_count:      1,
#             instance_modulo:     modulo,
#             boss_uuid:           @instance_uuid,
#           )
#         end

#         break
#       rescue ActiveRecord::WrappedDatabaseException
#         retry if (retries += 1) < 20
#         raise "failed after #{retries} retries"
#       end
#     end
#   end


#   def _save_record(record)
#     ActiveRecord::Base.connection_pool.with_connection do
#       record.touch
#       record.save!
#     end
#   end


#   def _destroy_record
#     my_record = ActiveRecord::Base.connection_pool.with_connection do
#       ProtocolRecord.where(instance_uuid: @instance_uuid).take
#     end
#     my_record.destroy! if my_record
#   end


#   def _read_records
#     all_records = ActiveRecord::Base.connection_pool.with_connection do
#       ProtocolRecord.where(group_uuid: @group_uuid).to_a
#     end

#     group_records = all_records.select{|rec| rec.updated_at > Time.now - 10.seconds}
#     dead_records  = all_records - group_records
#     my_record     = all_records.detect{|rec| rec.instance_uuid == @instance_uuid}

#     [my_record, group_records, dead_records]
#   end


#   def _get_boss_situation(group_records)
#     return [false, nil] if group_records.empty?

#     uuid, votes = group_records.group_by(&:boss_uuid)
#                                .inject({}){|result, (uuid, group)|
#                                   result[uuid] = group.size
#                                   result
#                                }.sort_by{|uuid, size| size}
#                                .last

#     boss_uuid = (votes > group_records.count/2.0) ? uuid : nil
#     boss_uuid = nil unless group_records.detect{|rec| rec.instance_uuid == boss_uuid}

#     boss_record = group_records.detect{|rec| rec.instance_uuid == boss_uuid}
#     am_boss = (boss_uuid == @instance_uuid)

#     [am_boss, boss_record]
#   end


#   def _elect_new_boss(my_record, group_records)
#     lowest_uuid = group_records.map(&:instance_uuid).sort.first

#     my_record.boss_uuid      = lowest_uuid
#     my_record.instance_count = group_records.count

#     _save_record(my_record)
#     # sleep(0.1)
#   end


#   def _allocate_modulo(my_record, group_records)
#     am_boss, boss_record = _get_boss_situation(group_records)
#     return if !boss_record

#     boss_instance_count = boss_record.instance_count

#     all_modulos = (0..boss_instance_count-1).to_a
#     taken_modulos = group_records.select{ |rec|
#       (rec.instance_modulo >= 0) && (rec.instance_modulo < boss_instance_count)
#     }.map(&:instance_modulo).sort

#     available_modulos = all_modulos - taken_modulos

#     available_modulos.each do |target_modulo|
#       begin
#         my_record.instance_modulo = target_modulo
#         my_record.instance_count  = group_records.count
#         _save_record(my_record)
#         break
#       rescue ActiveRecord::WrappedDatabaseException
#         # sleep(0.1)
#       end
#     end

#     # sleep(0.1)
#   end

# end
