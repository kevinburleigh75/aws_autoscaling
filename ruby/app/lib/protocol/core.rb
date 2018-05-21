class Protocol
  class Core
    def initialize(world:)
      @world = world
    end

    def process(process_time:)
      unless @world.has_group_records?
        @world.read_group_records
        @world.categorize_records

        unless @world.has_instance_record?
          @world.create_instance_record
          @world.clear_group_records
          sleep(0.01)
          return true
        end

        unless @world.has_boss_record?
          @world.update_boss_vote
          @world.clear_group_records
          sleep(0.01)
          return true
        end

        if @world.align_with_boss
          @world.save_record
        end

        if @world.am_boss?
          if @world.destroy_dead_records
            @world.clear_group_records
            sleep(0.01)
            return true
          end
        end

        if @world.allocate_modulo
          @world.save_record
          @world.clear_group_records
          sleep(0.01)
          return true
        end
      end

      if @world.am_boss?
        if not @world.has_next_boss_time?
          @world.compute_and_set_next_boss_time(current_time: process_time)
        end

        if @world.boss_block_should_be_called?(current_time: process_time)
          @world.call_boss_block
          @world.compute_and_set_next_boss_time(current_time: process_time)
        end
      else
        @world.clear_next_boss_time
      end

      if not @world.has_next_end_time?
        @world.compute_and_set_next_end_time(current_time: process_time)
      end

      if @world.end_block_should_be_called?(current_time: process_time)
        return false if @world.call_end_block
        @world.compute_and_set_next_end_time(current_time: process_time)
      end

      if not @world.has_next_work_time?
        @world.compute_and_set_next_work_time(current_time: process_time)
      end

      if @world.work_block_should_be_called?(current_time: process_time)
        @world.call_work_block
        @world.compute_and_set_next_work_time(current_time: process_time)
      end

      if not @world.has_next_update_time?
        @world.compute_and_set_next_update_time(current_time: process_time)
      end

      if @world.is_time_for_update?(current_time: process_time)
        @world.compute_and_set_next_update_time(current_time: process_time)
        @world.save_record
        @world.clear_group_records
      end

      @world.compute_next_wake_time(current_time: process_time)
      @world.sleep_until_next_event

      return true
    end
  end
end
