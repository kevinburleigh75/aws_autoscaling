class CreateCalcResults < ActiveRecord::Migration[5.1]
  def change
    create_table :calc_results do |t|
      t.uuid     :uuid,                 null: false
      t.uuid     :calc_request_uuid,    null: false

      t.uuid     :ecosystem_uuid,       null: false
      t.uuid     :learner_uuid,         null: false
      t.boolean  :has_been_reported,    null: false
      t.datetime :reported_at

      t.timestamps                      null: false
    end

    add_index :calc_results,  :uuid,
                              unique: true
    add_index :calc_results,  :calc_request_uuid,
                              unique: true
    add_index :calc_results,  :has_been_reported
    add_index :calc_results,  :created_at
  end
end
