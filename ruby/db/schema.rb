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

ActiveRecord::Schema.define(version: 20171012134937) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "exper_records", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "uuid1", null: false
    t.uuid "uuid2", null: false
    t.uuid "uuid3", null: false
    t.uuid "uuid4", null: false
    t.uuid "uuid5", null: false
    t.uuid "uuid6", null: false
    t.uuid "uuid7", null: false
    t.uuid "uuid8", null: false
    t.uuid "uuid9", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uuid"], name: "index_exper_records_on_uuid"
  end

  create_table "protocol_records", force: :cascade do |t|
    t.string "protocol_name", null: false
    t.uuid "group_uuid", null: false
    t.uuid "instance_uuid", null: false
    t.integer "instance_count", null: false
    t.integer "instance_modulo", null: false
    t.uuid "boss_uuid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_uuid", "instance_modulo"], name: "index_protocol_records_on_group_uuid_and_instance_modulo", unique: true
    t.index ["group_uuid"], name: "index_protocol_records_on_group_uuid"
    t.index ["instance_uuid"], name: "index_protocol_records_on_instance_uuid", unique: true
  end

  create_table "request_records", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.integer "partition_value", null: false
    t.boolean "has_been_processed", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_request_records_on_created_at"
    t.index ["has_been_processed"], name: "index_request_records_on_has_been_processed"
    t.index ["uuid"], name: "index_request_records_on_uuid"
  end

  create_table "response_records", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_response_records_on_created_at"
    t.index ["uuid"], name: "index_response_records_on_uuid"
  end

end
