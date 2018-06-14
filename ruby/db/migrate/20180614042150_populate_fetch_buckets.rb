class PopulateFetchBuckets < ActiveRecord::Migration[5.1]
  class FetchBucket < ActiveRecord::Base
  end

  def up
    fetch_buckets = 720.times.map do |bucket_num|
      FetchBucket.new(
        bucket_uuid: SecureRandom.uuid.to_s,
        bucket_num:  bucket_num,
      )
    end

    FetchBucket.import fetch_buckets
  end

  def down
    FetchBucket.find_each do |fetch_bucket|
      fetch_bucket.delete!
    end
  end
end
