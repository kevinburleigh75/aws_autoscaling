class CreateFetchCourseClients < ActiveRecord::Migration[5.1]
  def change
    create_table :fetch_course_clients do |t|
      t.uuid    :client_uuid,  null: false
      t.string  :client_name,  null: false

      t.timestamps null: false
    end

    add_index :fetch_course_clients,  :client_uuid,
                                      unique: true

    add_index :fetch_course_clients,  :client_name,
                                      unique: true
  end
end
