class CreateCourseBundles < ActiveRecord::Migration[5.1]
  def change
    create_table :course_bundles do |t|
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

    add_index :course_bundles, :uuid,
                               unique: true

    add_index :course_bundles, :course_uuid

    add_index :course_bundles, :course_event_seqnum_lo

    add_index :course_bundles, :course_event_seqnum_hi

    add_index :course_bundles, :has_been_processed

    add_index :course_bundles, :waiting_since

    add_index :course_bundles, [:course_uuid, :course_event_seqnum_lo],
                                unique: true,
                                name: 'index_cbs_on_cu_cesl'

    add_index :course_bundles, [:course_uuid, :course_event_seqnum_hi],
                                unique: true,
                                name: 'index_cbs_on_cu_cesh'

    add_index :course_bundles, [:course_uuid, :course_event_seqnum_lo, :course_event_seqnum_hi],
                                name: 'index_cbs_on_cu_cesl_cesh'
  end
end
