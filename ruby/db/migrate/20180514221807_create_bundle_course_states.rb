class CreateBundleCourseStates < ActiveRecord::Migration[5.1]
  def change
    create_table :bundle_course_states do |t|
      t.uuid      :course_uuid,         null: false
      t.integer   :last_bundled_seqnum, null: false

      t.timestamps null: false
    end

    add_index :bundle_course_states,  :course_uuid,
                                      unique: true

    add_index :bundle_course_states,  [:last_bundled_seqnum, :course_uuid],
                                      name: 'index_bcss_on_lbs_cu'
  end
end
