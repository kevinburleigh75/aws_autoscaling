class CreateCourseClients < ActiveRecord::Migration[5.1]
  def change
    create_table :course_clients do |t|
      t.uuid    :uuid,       null: false
      t.string  :name,       null: false

      t.timestamps null: false
    end

    add_index :course_clients, :uuid,
                               unique: true

    add_index :course_clients, :name,
                               unique: true
  end
end
