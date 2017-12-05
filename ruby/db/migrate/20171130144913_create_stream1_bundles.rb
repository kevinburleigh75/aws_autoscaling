class CreateStream1Bundles < ActiveRecord::Migration[5.1]
  def change
    create_table :stream1_bundles do |t|
      t.uuid      :uuid,                     null: false
      t.uuid      :course_uuid,              null: false
      t.integer   :course_event_seqnum_lo,   null: false
      t.integer   :course_event_seqnum_hi,   null: false
      t.integer   :size,                     null: false
      t.boolean   :is_open,                  null: false
      t.boolean   :has_been_processed,       null: false
      t.timestamp :waiting_since,            null: false

      t.timestamps null: false
    end

    add_index :stream1_bundles, :uuid,
                                unique: true

    add_index :stream1_bundles, :course_uuid

    add_index :stream1_bundles, :course_event_seqnum_lo

    add_index :stream1_bundles, :course_event_seqnum_hi

    add_index :stream1_bundles, :has_been_processed

    add_index :stream1_bundles, :waiting_since

    add_index :stream1_bundles, [:course_uuid, :course_event_seqnum_lo],
                                unique: true,
                                name: 'index_s1bs_on_cu_cesl'

    add_index :stream1_bundles, [:course_uuid, :course_event_seqnum_hi],
                                unique: true,
                                name: 'index_s1bs_on_cu_cesh'

    add_index :stream1_bundles, [:course_uuid, :course_event_seqnum_lo, :course_event_seqnum_hi],
                                name: 'index_s1bs_on_cu_cesl_cesh'
  end
end
