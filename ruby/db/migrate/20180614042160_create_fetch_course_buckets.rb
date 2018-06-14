class CreateFetchCourseBuckets < ActiveRecord::Migration[5.1]
  def change
    create_table :fetch_course_buckets do |t|
      t.uuid    :course_uuid, null: false
      t.integer :bucket_num,  null: false

      t.timestamps null: false
    end

    add_index :fetch_course_buckets,  :course_uuid,
                                      unique: true

    add_index :fetch_course_buckets, [:bucket_num, :course_uuid]

  end
end
