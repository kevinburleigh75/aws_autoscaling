class CreateStream1BundleEntries < ActiveRecord::Migration[5.1]
  def change
    create_table :stream1_bundle_entries do |t|
      t.uuid :course_event_uuid,  null: false
      t.uuid :stream_bundle_uuid, null: false

      t.timestamps null: false
    end

    add_index :stream1_bundle_entries, :course_event_uuid,
                                       unique: true

    add_index :stream1_bundle_entries, :stream_bundle_uuid
  end
end
