class CreateCalcRequests < ActiveRecord::Migration[5.1]
  def change
    create_table :calc_requests do |t|
      t.uuid     :uuid,                 null: false
      t.integer  :partition_value,      null: false

      t.uuid     :ecosystem_uuid,       null: false
      t.uuid     :learner_uuid,         null: false
      t.boolean  :has_been_processed,   null: false
      t.datetime :processed_at

      t.timestamps                      null: false
    end

    add_index :calc_requests, :uuid,
                              unique: true
    add_index :calc_requests, :learner_uuid
    add_index :calc_requests, [:learner_uuid, :ecosystem_uuid]
    add_index :calc_requests, :has_been_processed
    add_index :calc_requests, :created_at
  end
end
