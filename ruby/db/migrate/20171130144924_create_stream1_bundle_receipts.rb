class CreateStream1BundleReceipts < ActiveRecord::Migration[5.1]
  def change
    create_table :stream1_bundle_receipts do |t|
      t.uuid     :stream1_client_uuid,   null: false
      t.uuid     :stream1_bundle_uuid,   null: false
      t.boolean  :has_been_acknowledged, null: false

      t.timestamps null: false
    end
  end
end
