class CreateResponseRecords < ActiveRecord::Migration[5.1]
  def change
    create_table :response_records do |t|
      t.uuid     :uuid,           null: false

      t.timestamps                null: false
    end

    add_index  :response_records,  :uuid
    add_index  :response_records,  :created_at
  end
end
