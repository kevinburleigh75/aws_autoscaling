class CreateFetchBuckets < ActiveRecord::Migration[5.1]
  def change
    create_table :fetch_buckets do |t|
      t.uuid    :bucket_uuid,   null: false
      t.integer :bucket_num,    null: false

      t.timestamps  null: false
    end

    add_index :fetch_buckets, :bucket_uuid,
                              unique: true

    add_index :fetch_buckets, :bucket_num,
                              unique: true
  end
end
