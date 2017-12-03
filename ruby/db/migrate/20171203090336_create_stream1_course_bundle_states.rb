class CreateStream1CourseBundleStates < ActiveRecord::Migration[5.1]
  def change
    create_table :stream1_course_bundle_states do |t|
      t.uuid      :course_uuid,         null: false
      t.boolean   :needs_attention,     null: false
      t.timestamp :waiting_since,       null: false

      t.timestamps null: false
    end

    add_index :stream1_course_bundle_states, :course_uuid,
                                             unique: true

    add_index :stream1_course_bundle_states, :needs_attention

    add_index :stream1_course_bundle_states, :waiting_since

    add_index :stream1_course_bundle_states, [:needs_attention, :waiting_since],
                                             name: 'index_s1cbss_on_na_ws'
  end
end
