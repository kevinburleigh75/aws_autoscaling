class CreateStream1Clients < ActiveRecord::Migration[5.1]
  def change
    create_table :stream1_clients do |t|
      t.uuid    :uuid,       null: false
      t.string  :name,       null: false
      # t.boolean :is_prepped, null: false
      # t.boolean :is_active,  null: false

      t.timestamps null: false
    end

    add_index :stream1_clients, :uuid,
                                unique: true

    add_index :stream1_clients, :name,
                                unique: true
  end
end
