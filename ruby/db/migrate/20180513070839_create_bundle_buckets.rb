class CreateBundleBuckets < ActiveRecord::Migration[5.1]
  def change
    create_table :bundle_buckets do |t|
      t.uuid    :bucket_uuid,   null: false
      t.integer :bucket_num,    null: false

      t.timestamps  null: false
    end

    add_index :bundle_buckets,  :bucket_uuid,
                                unique: true

    add_index :bundle_buckets, :bucket_num,
                               unique: true
  end
end
