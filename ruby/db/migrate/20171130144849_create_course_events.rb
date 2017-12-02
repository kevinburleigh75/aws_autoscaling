class CreateCourseEvents < ActiveRecord::Migration[5.1]
  def change
    create_table :course_events do |t|
      t.uuid      :course_uuid,     null: false
      t.integer   :course_seqnum,   null: false
      t.string    :event_type,      null: false
      t.uuid      :event_uuid,      null: false
      t.datetime  :event_time,      null: false

      t.integer   :partition_value,                null: false
      t.boolean   :has_been_processed_by_stream_1, null: false
      t.boolean   :has_been_processed_by_stream_2, null: false

      t.timestamps null: false
    end

    add_index :course_events, :course_uuid

    add_index :course_events, :has_been_processed_by_stream_1

    add_index :course_events, :has_been_processed_by_stream_2

    add_index :course_events, [:course_uuid, :course_seqnum],
                              unique: true

    add_index :course_events, [:has_been_processed_by_stream_1, :course_uuid, :course_seqnum],
                              name: 'index_ce_on_hbpbs1_cu_csn'

    add_index :course_events, [:has_been_processed_by_stream_2, :course_uuid, :course_seqnum],
                              name: 'index_ce_on_hbpbs2_cu_csn'
  end
end
