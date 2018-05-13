class PopulateBundleBuckets < ActiveRecord::Migration[5.1]
  class BundleBucket < ActiveRecord::Base
  end

  def up
    bundle_buckets = 720.times.map do |bucket_num|
      BundleBucket.new(
        bucket_uuid: SecureRandom.uuid.to_s,
        bucket_num:  bucket_num,
      )
    end

    BundleBucket.import bundle_buckets
  end

  def down
    BundleBucket.find_each do |bundle_bucket|
      bundle_bucket.delete!
    end
  end
end
