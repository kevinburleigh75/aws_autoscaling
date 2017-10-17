class CreateRequestRecords < ActiveRecord::Migration[5.1]
  def change
    create_table :request_records do |t|
      t.uuid     :uuid,                 null: false
      t.integer  :partition_value,      null: false
      t.boolean  :has_been_processed,   null: false

      t.timestamps                      null: false
    end

    add_index  :request_records,  :uuid
    add_index  :request_records,  :created_at
    add_index  :request_records,  :has_been_processed
  end
end
