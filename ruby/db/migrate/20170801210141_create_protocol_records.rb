class CreateProtocolRecords < ActiveRecord::Migration[5.1]
  def change
    create_table :protocol_records do |t|
      t.uuid     :group_uuid,           null: false
      t.string   :group_desc,           null: false

      t.uuid     :instance_uuid,        null: false
      t.string   :instance_desc,        null: false
      t.integer  :instance_count,       null: false
      t.integer  :instance_modulo,      null: false

      t.uuid     :boss_uuid,            null: false

      t.timestamp :next_end_time
      t.timestamp :next_boss_time
      t.timestamp :next_work_time
      t.timestamp :next_update_time

      t.timestamps                      null: false
    end

    add_index  :protocol_records, :instance_uuid,
                                  unique: true

    add_index  :protocol_records, [:group_uuid, :instance_modulo],
                                  unique: true
  end
end
