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
end
