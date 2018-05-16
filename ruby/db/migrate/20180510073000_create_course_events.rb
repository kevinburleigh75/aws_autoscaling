class CreateCourseEvents < ActiveRecord::Migration[5.1]
  def change
    create_table :course_events do |t|
      t.uuid      :course_uuid,     null: false
      t.integer   :course_seqnum,   null: false
      t.string    :event_type,      null: false
      t.uuid      :event_uuid,      null: false
      t.datetime  :event_time,      null: false

      t.uuid      :bundle_uuid

      t.timestamps null: false
    end

    add_index :course_events, :event_uuid,
                              unique: true

    add_index :course_events, [:course_uuid, :course_seqnum],
                              unique: true

    # add_index :course_events, [:bundle_uuid, :course_seqnum, :course_uuid],
    #                           name: 'index_ce_on_bu_csn_cu'

    add_index :course_events, [:bundle_uuid, :course_uuid, :course_seqnum],
                              name: 'index_ce_on_bu_cu_csn'

  end
end
