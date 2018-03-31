class CreateRequestRecords < ActiveRecord::Migration[5.1]
  def change
    create_table :request_records do |t|
      t.uuid    :request_record_uuid, null: false
      t.string  :request_fullpath,    null: false
      t.float   :request_elapsed,     null: false
      t.string  :aws_instance_id,     null: false
      t.string  :aws_asg_name,        null: false
      t.string  :aws_lc_image_id,     null: false
      t.boolean :has_been_processed,  null: false

      t.timestamps                    null: false
    end

    add_index :request_records, [:has_been_processed, :created_at]

    add_index :request_records, [:aws_instance_id, :created_at, :request_elapsed],
                                name: 'index_rrs_on_aii_ca_re'
  end
end
