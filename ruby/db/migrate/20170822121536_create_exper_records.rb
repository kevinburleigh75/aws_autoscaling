class CreateExperRecords < ActiveRecord::Migration[5.1]
  def change
    create_table :exper_records do |t|
      t.uuid     :uuid,           null: false

      t.timestamps                null: false
    end

    add_index  :exper_records,  :uuid
  end
end
