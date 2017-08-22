class CreateExperRecords < ActiveRecord::Migration[5.1]
  def change
    create_table :exper_records do |t|
      t.uuid     :uuid,           null: false

      t.uuid     :uuid1,          null: false
      t.uuid     :uuid2,          null: false
      t.uuid     :uuid3,          null: false
      t.uuid     :uuid4,          null: false
      t.uuid     :uuid5,          null: false
      t.uuid     :uuid6,          null: false
      t.uuid     :uuid7,          null: false
      t.uuid     :uuid8,          null: false
      t.uuid     :uuid9,          null: false

      t.timestamps                null: false
    end

    add_index  :exper_records,  :uuid
  end
end
