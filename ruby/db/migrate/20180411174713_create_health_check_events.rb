class CreateHealthCheckEvents < ActiveRecord::Migration[5.1]
  def change
    create_table :health_check_events do |t|
      t.uuid    :health_check_uuid, null: false
      t.string  :instance_id,       null: false
      t.string  :health_status,     null: false

      t.timestamps                  null: false
    end

    add_index :health_check_events, :health_check_uuid,
                                    unique: true

    add_index :health_check_events, :instance_id

    add_index :health_check_events, :health_status

    add_index :health_check_events, :created_at
  end
end
