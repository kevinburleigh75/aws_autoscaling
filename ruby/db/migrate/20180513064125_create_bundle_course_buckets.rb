class CreateBundleCourseBuckets < ActiveRecord::Migration[5.1]
  def change
    create_table :bundle_course_buckets do |t|
      t.uuid    :course_uuid, null: false
      t.integer :bucket_num,  null: false

      t.timestamps null: false
    end

    add_index :bundle_course_buckets, :course_uuid,
                                      unique: true

    add_index :bundle_course_buckets, [:bucket_num, :course_uuid]
  end
end
