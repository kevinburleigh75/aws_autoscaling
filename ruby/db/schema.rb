# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180329152044) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "autoscaling_requests", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "group_uuid", null: false
    t.string "request_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "protocol_records", force: :cascade do |t|
    t.uuid "group_uuid", null: false
    t.uuid "instance_uuid", null: false
    t.integer "instance_count", null: false
    t.integer "instance_modulo", null: false
    t.string "instance_desc", null: false
    t.uuid "boss_uuid", null: false
    t.datetime "next_end_time"
    t.datetime "next_boss_time"
    t.datetime "next_work_time"
    t.datetime "next_wake_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_uuid", "instance_modulo"], name: "index_protocol_records_on_group_uuid_and_instance_modulo", unique: true
    t.index ["group_uuid"], name: "index_protocol_records_on_group_uuid"
    t.index ["instance_uuid"], name: "index_protocol_records_on_instance_uuid", unique: true
  end

  create_table "request_records", force: :cascade do |t|
    t.uuid "request_record_uuid", null: false
    t.string "request_fullpath", null: false
    t.float "request_elapsed", null: false
    t.string "aws_instance_id", null: false
    t.string "aws_asg_name", null: false
    t.string "aws_lc_image_id", null: false
    t.boolean "has_been_processed", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["aws_instance_id", "created_at", "request_elapsed"], name: "index_rrs_on_aii_ca_re"
    t.index ["has_been_processed", "created_at"], name: "index_request_records_on_has_been_processed_and_created_at"
  end

end
