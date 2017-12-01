class CreateCourseStates < ActiveRecord::Migration[5.1]
  def change
    create_table :course_states do |t|
      t.uuid    :course_uuid, null: false
      t.boolean :is_archived, null: false
    end
  end
end
