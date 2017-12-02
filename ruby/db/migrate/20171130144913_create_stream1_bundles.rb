class CreateStream1Bundles < ActiveRecord::Migration[5.1]
  def change
    create_table :stream1_bundles do |t|
      t.uuid    :uuid,                     null: false
      t.integer :seqnum,                   null: false
      t.uuid    :course_uuid,              null: false
      t.integer :course_event_seqnum_lo,   null: false
      t.integer :course_event_seqnum_hi,   null: false
      t.boolean :is_open,                  null: false

      t.timestamps null: false

    end
  end
end
