class AddNotNullToDesiredCapacity < ActiveRecord::Migration[5.1]
  def change
    change_column_null :autoscaling_requests, :desired_capacity, false
  end
end
