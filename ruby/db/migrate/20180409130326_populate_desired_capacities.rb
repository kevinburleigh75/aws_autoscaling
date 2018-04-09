class PopulateDesiredCapacities < ActiveRecord::Migration[5.1]
  class MigrationAutoscalingRequest < ActiveRecord::Base
    self.table_name = :autoscaling_requests
  end

  def change
    reversible do |dir|
      dir.up do
        loop do
          num_updates = update_autoscaling_requests(
            condition:            'desired_capacity IS NULL',
            new_desired_capacity: -1,
          )
          break if num_updates == 0
          sleep(0.05)
        end
      end

      dir.down do
        loop do
          num_updates = update_autoscaling_requests(
            condition:            'desired_capacity = -1',
            new_desired_capacity: nil,
          )
          break if num_updates == 0
          sleep(0.05)
        end
      end
    end
  end

  protected

  def update_autoscaling_requests(condition:, new_desired_capacity:)
    num_updated_requests = MigrationAutoscalingRequest.transaction do
      sql_requests_to_process = %Q{
        SELECT * FROM autoscaling_requests
        WHERE #{condition}
        LIMIT 50
        FOR UPDATE
      }.gsub(/\n\s*/, ' ')

      autoscaling_requests = MigrationAutoscalingRequest.find_by_sql(sql_requests_to_process)

      autoscaling_requests.each do |autoscaling_request|
        autoscaling_request.desired_capacity = new_desired_capacity
        autoscaling_request.save!
      end

      autoscaling_requests.count
    end
  end
end
