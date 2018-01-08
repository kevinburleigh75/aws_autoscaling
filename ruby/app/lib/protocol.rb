class Protocol
  class Core
    def initialize(world:)
      @world = world
    end

    def process(process_time:)
      @world.read_group_records
      @world.categorize_records

      unless @world.has_instance_record?
        @world.create_instance_record
        return true
      end

      if not @world.has_boss_record?
        @world.update_boss_vote
        return true
      end

      @world.align_with_boss

      if @world.allocate_modulo
        return true
      end

      if @world.am_boss?
        if not @world.has_next_boss_time?
          @world.compute_and_set_next_boss_time(current_time: process_time)
        end

        @world.destroy_dead_records

        if @world.boss_block_should_be_called?(current_time: process_time)
          @world.call_boss_block
          @world.compute_and_set_next_boss_time(current_time: process_time)
        end
      else
        @world.clear_next_boss_time
      end

      if @world.end_block_should_be_called?(current_time: process_time)
        return false if @world.call_end_block
        @world.compute_and_set_next_end_time(current_time: process_time)
      end

      if @world.work_block_should_be_called?(current_time: process_time)
        @world.call_work_block
        @world.compute_and_set_next_work_time(current_time: process_time)
      end

      @world.compute_next_wake_time(current_time: process_time)
      @world.save_record

      @world.sleep_until_next_event

      return true
    end
  end


  def initialize(min_end_interval:  nil,
                 end_block:         nil,
                 min_boss_interval: nil,
                 boss_block:        nil,
                 min_work_interval: nil,
                 work_block:        nil,
                 min_wake_interval: nil,
                 group_uuid:,
                 instance_uuid:,
                 instance_desc:,
                 dead_record_timeout:,
                 reference_time:,
                 timing_modulo:,
                 timing_offset:)
    @min_end_interval  = min_end_interval
    @end_block         = end_block
    @min_boss_interval = min_boss_interval
    @boss_block        = boss_block
    @min_work_interval = min_work_interval
    @work_block        = work_block
    @min_wake_interval = min_wake_interval || 0.25.seconds

    @group_uuid          = group_uuid
    @instance_uuid       = instance_uuid
    @instance_desc       = instance_desc
    @dead_record_timeout = dead_record_timeout
    @reference_time      = reference_time
    @timing_modulo       = timing_modulo
    @timing_offset       = timing_offset

    @core = Core.new(world: self)
  end

  def read_group_records
    @group_records = Protocol.read_group_records(group_uuid: @group_uuid)
  end

  def categorize_records
    @instance_record, @live_records, @dead_records = Protocol.categorize_records(
      instance_uuid:       @instance_uuid,
      dead_record_timeout: @dead_record_timeout,
      group_records:       @group_records,
    )
  end

  def has_instance_record?
    !!@instance_record
  end

  def create_instance_record
    Protocol.create_record(
      group_uuid:    @group_uuid,
      instance_uuid: @instance_uuid,
      instance_desc: @instance_desc,
    )
  end

  def has_boss_record?
    @am_boss, @boss_record = Protocol.get_boss_situation(
      instance_uuid: @instance_uuid,
      live_records:  @live_records,
    )
    !!@boss_record
  end

  def align_with_boss
    @instance_record.boss_uuid = @boss_record.instance_uuid
  end

  def update_boss_vote
    Protocol.update_boss_vote(
      instance_record: @instance_record,
      live_records:    @live_records,
    )
  end

  def allocate_modulo
    Protocol.allocate_modulo(
      instance_record: @instance_record,
      live_records:    @live_records,
      boss_record:     @boss_record,
    )
  end

  def am_boss?
    !!@am_boss
  end

  def has_next_boss_time?
    return true if (@min_boss_interval.nil? || @boss_block.nil?)
    return !@instance_record.next_boss_time.nil?
  end

  def clear_next_boss_time
    @instance_record.next_boss_time = nil
  end

  def compute_and_set_next_boss_time(current_time:)
    time_to_use =
      if @instance_record.next_boss_time.nil?
        current_time
      else
        @instance_record.next_boss_time + 1e-5.seconds
      end

    @instance_record.next_boss_time = Protocol.compute_next_time(
      current_time:    time_to_use,
      reference_time:  @reference_time,
      timing_modulo:   @timing_modulo,
      timing_offset:   @timing_offset,
      instance_count:  @instance_record.instance_count,
      instance_modulo: @instance_record.instance_modulo,
      interval:        @min_boss_interval
    )

    if @instance_record.next_boss_time < current_time
      @instance_record.next_boss_time = current_time
    end
  end

  def compute_and_set_next_work_time(current_time:)
    time_to_use =
      if @instance_record.next_work_time.nil?
        current_time
      else
        @instance_record.next_work_time + 1e-5.seconds
      end

    @instance_record.next_work_time = Protocol.compute_next_time(
      current_time:    time_to_use,
      reference_time:  @reference_time,
      timing_modulo:   @timing_modulo,
      timing_offset:   @timing_offset,
      instance_count:  @instance_record.instance_count,
      instance_modulo: @instance_record.instance_modulo,
      interval:        @min_work_interval
    )

    if @instance_record.next_work_time < current_time
      @instance_record.next_work_time = current_time
    end
  end

  def compute_and_set_next_end_time(current_time:)
    time_to_use =
      if @instance_record.next_end_time.nil?
        current_time
      else
        @instance_record.next_end_time + 1e-5.seconds
      end

    @instance_record.next_end_time = Protocol.compute_next_time(
      current_time:    time_to_use,
      reference_time:  @reference_time,
      timing_modulo:   @timing_modulo,
      timing_offset:   @timing_offset,
      instance_count:  @instance_record.instance_count,
      instance_modulo: @instance_record.instance_modulo,
      interval:        @min_end_interval
    )

    if @instance_record.next_end_time < current_time
      @instance_record.next_end_time = current_time
    end
  end

  def destroy_dead_records
    @dead_records.map(&:destroy)
  end

  def boss_block_should_be_called?(current_time:)
    return false if @min_boss_interval.nil? || @boss_block.nil? || @instance_record.next_boss_time.nil?
    return current_time > @instance_record.next_boss_time
  end

  def call_boss_block
    @boss_block.call(protocol: self)
  end

  def work_block_should_be_called?(current_time:)
    return false if @min_work_interval.nil? || @work_block.nil? || @instance_record.next_work_time.nil?
    return current_time > @instance_record.next_work_time
  end

  def call_work_block
    @work_block.call(protocol: self)
  end

  def end_block_should_be_called?(current_time:)
    return false if @min_end_interval.nil? || @end_block.nil? || @instance_record.next_end_time.nil?
    return current_time > @instance_record.next_end_time
  end

  def call_end_block
    @end_block.call(protocol: self)
  end

  def save_record
    @instance_record.instance_count = @live_records.count
    Protocol.save_record(record: @instance_record)
  end

  def compute_next_wake_time(current_time:)
    @instance_record.next_wake_time = Protocol.compute_next_time(
      current_time:    current_time,
      reference_time:  @reference_time,
      timing_modulo:   @timing_modulo,
      timing_offset:   @timing_offset,
      instance_count:  @instance_record.instance_count,
      instance_modulo: @instance_record.instance_modulo,
      interval:        @min_wake_interval
    )

    @instance_record.next_wake_time = [
      @instance_record.next_end_time,
      @instance_record.next_boss_time,
      @instance_record.next_work_time,
      @instance_record.next_wake_time,
    ].compact.min
  end

  def sleep_until_next_event
    delay = [@instance_record.next_wake_time - Time.now, 0.001].max
    sleep(delay)
  end

  def run
    begin
      loop do
        break unless @core.process(process_time: Time.now)
      end
    rescue Interrupt => ex
      # puts 'exiting'
    rescue Exception => ex
      raise ex
    ensure
      destroy_record
    end
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
      record.updated_at = Time.now
      record.save!
    end
  end

  def destroy_record
    instance_record = ActiveRecord::Base.connection_pool.with_connection do
      ProtocolRecord.where(instance_uuid: @instance_uuid).take
    end
    instance_record.destroy! if instance_record
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
