class Protocol
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

    @core = Protocol::Core.new(world: self)
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

  def group_uuid
    @group_uuid
  end

  def instance_uuid
    @instance_uuid
  end

  def am_boss?
    !!@am_boss
  end

  def count
    @instance_record.instance_count
  end

  def modulo
    @instance_record.instance_modulo
  end

  def read_group_records
    @group_records = Protocol::Helpers.read_group_records(group_uuid: @group_uuid)
  end

  def categorize_records
    @instance_record, @live_records, @dead_records = Protocol::Helpers.categorize_records(
      instance_uuid:       @instance_uuid,
      dead_record_timeout: @dead_record_timeout,
      group_records:       @group_records,
    )
  end

  def has_instance_record?
    !!@instance_record
  end

  def create_instance_record
    Protocol::Helpers.create_record(
      group_uuid:    @group_uuid,
      instance_uuid: @instance_uuid,
      instance_desc: @instance_desc,
    )
  end

  def has_boss_record?
    @am_boss, @boss_record = Protocol::Helpers.get_boss_situation(
      instance_uuid: @instance_uuid,
      live_records:  @live_records,
    )
    !!@boss_record
  end

  def align_with_boss
    @instance_record.boss_uuid = @boss_record.instance_uuid
  end

  def update_boss_vote
    Protocol::Helpers.update_boss_vote(
      instance_record: @instance_record,
      live_records:    @live_records,
    )
  end

  def allocate_modulo
    Protocol::Helpers.allocate_modulo(
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

    @instance_record.next_boss_time = Protocol::Helpers.compute_next_time(
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

    @instance_record.next_work_time = Protocol::Helpers.compute_next_time(
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

    @instance_record.next_end_time = Protocol::Helpers.compute_next_time(
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
    Protocol::Helpers.save_record(record: @instance_record)
  end

  def compute_next_wake_time(current_time:)
    @instance_record.next_wake_time = Protocol::Helpers.compute_next_time(
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

  def destroy_record
    instance_record = ActiveRecord::Base.connection_pool.with_connection do
      ProtocolRecord.where(instance_uuid: @instance_uuid).take
    end
    instance_record.destroy! if instance_record
  end
end
