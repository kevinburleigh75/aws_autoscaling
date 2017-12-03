class CreateStream1BundleEntries < ActiveRecord::Migration[5.1]
  def change
    create_table :stream1_bundle_entries do |t|
      t.uuid :course_event_uuid,  null: false
      t.uuid :stream_bundle_uuid, null: false

      t.timestamps null: false
    end
  end
end
