class CreateCourseStates < ActiveRecord::Migration[5.1]
  def change
    create_table :course_states do |t|
      t.uuid    :course_uuid, null: false
      t.boolean :is_archived, null: false
    end

    add_index :course_states, :course_uuid,
                              unique: true
  end
end
