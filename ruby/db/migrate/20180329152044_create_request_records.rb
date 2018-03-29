class CreateRequestRecords < ActiveRecord::Migration[5.1]
  def change
    create_table :request_records do |t|
      t.string  :instance_id,         null: false
      t.boolean :has_been_processed,  null: false

      t.timestamps                    null: false
    end

    add_index :request_records, [:has_been_processed, :created_at]
  end
end
