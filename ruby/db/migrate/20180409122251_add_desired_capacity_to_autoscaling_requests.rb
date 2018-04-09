class AddDesiredCapacityToAutoscalingRequests < ActiveRecord::Migration[5.1]
  def change
    add_column :autoscaling_requests, :desired_capacity, :integer
  end
end
