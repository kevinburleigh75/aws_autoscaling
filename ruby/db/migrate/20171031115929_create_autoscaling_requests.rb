class CreateAutoscalingRequests < ActiveRecord::Migration[5.1]
  def change
    create_table :autoscaling_requests do |t|
      t.uuid     :uuid,                 null: false

      t.uuid     :group_uuid,           null: false
      t.string   :request_type,         null: false

      t.timestamps                      null: false
    end
  end
end
