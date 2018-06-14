class CreateTempCourseEventMetadata < ActiveRecord::Migration[5.1]
  def change
    create_table :temp_course_event_metadata do |t|
      t.uuid      :course_uuid,                 null: false
      t.integer   :last_created_course_seqnum,  null: false

      t.timestamps null: false
    end

    add_index :temp_course_event_metadata,  :course_uuid,
                                            unique: true

    add_index :temp_course_event_metadata,  :created_at

    add_index :temp_course_event_metadata,  :updated_at
  end
end
