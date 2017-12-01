class CreateStream1Clients < ActiveRecord::Migration[5.1]
  def change
    create_table :stream1_clients do |t|
      t.uuid    :uuid,       null: false
      t.boolean :is_prepped, null: false
      t.boolean :is_active,  null: false

      t.timestamps
    end
  end
end
