class CreateCourseBundleEntries < ActiveRecord::Migration[5.1]
  def change
    create_table :course_bundle_entries do |t|
      t.uuid :course_event_uuid,  null: false
      t.uuid :course_bundle_uuid, null: false

      t.timestamps null: false
    end

    add_index :course_bundle_entries, :course_event_uuid,
                                      unique: true

    add_index :course_bundle_entries, :course_bundle_uuid
  end
end
