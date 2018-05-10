class CreateCourseClientStates < ActiveRecord::Migration[5.1]
  def change
    create_table :course_client_states do |t|
      t.uuid      :client_uuid,                  null: false
      t.uuid      :course_uuid,                  null: false
      t.integer   :last_confirmed_course_seqnum, null: false
      t.boolean   :needs_attention,              null: false
      t.timestamp :waiting_since,                null: false
    end

    add_index :course_client_states, :client_uuid

    add_index :course_client_states, :course_uuid

    add_index :course_client_states, :needs_attention

    add_index :course_client_states, :waiting_since

    add_index :course_client_states, [:needs_attention, :client_uuid, :course_uuid],
                                      name: 'index_ccss_on_na_cu_cu'

    add_index :course_client_states, [:client_uuid, :course_uuid],
                                      unique: true,
                                      name: 'index_ccss_on_cu_cu'

    add_index :course_client_states, [:client_uuid, :course_uuid, :last_confirmed_course_seqnum],
                                      name: 'index_ccss_on_cu_cu_lccs'
  end
end
