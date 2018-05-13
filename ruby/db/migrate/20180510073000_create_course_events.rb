class CreateCourseEvents < ActiveRecord::Migration[5.1]
  def change
    create_table :course_events do |t|
      t.uuid      :course_uuid,     null: false
      t.integer   :course_seqnum,   null: false
      t.string    :event_type,      null: false
      t.uuid      :event_uuid,      null: false
      t.datetime  :event_time,      null: false

      t.boolean   :has_been_bundled, null: false

      t.timestamps null: false
    end

    add_index :course_events, :event_uuid,
                              unique: true

    add_index :course_events, [:course_uuid, :course_seqnum],
                              unique: true

    add_index :course_events, [:course_uuid, :has_been_bundled, :course_seqnum],
                              name: 'index_ces_on_cu_hbb_csn'

    add_index :course_events, [:event_uuid, :has_been_bundled, :course_seqnum],
                              name: 'index_ces_on_eu_hbb_csn'

    add_index :course_events, :course_uuid

    add_index :course_events, :has_been_bundled

    add_index :course_events, [:has_been_bundled, :course_uuid, :course_seqnum],
                              name: 'index_ce_on_hbb_cu_csn'

  end
end
