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

ActiveRecord::Schema.define(version: 20171130152950) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "course_events", force: :cascade do |t|
    t.uuid "course_uuid", null: false
    t.integer "course_seqnum", null: false
    t.string "event_type", null: false
    t.uuid "event_uuid", null: false
    t.datetime "event_time", null: false
    t.integer "partition_value", null: false
    t.boolean "has_been_processed_by_stream_1", null: false
    t.boolean "has_been_processed_by_stream_2", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_uuid", "course_seqnum"], name: "index_course_events_on_course_uuid_and_course_seqnum", unique: true
    t.index ["course_uuid"], name: "index_course_events_on_course_uuid"
    t.index ["has_been_processed_by_stream_1", "course_uuid", "course_seqnum"], name: "index_ce_on_hbpbs1_cu_csn"
    t.index ["has_been_processed_by_stream_1"], name: "index_course_events_on_has_been_processed_by_stream_1"
    t.index ["has_been_processed_by_stream_2", "course_uuid", "course_seqnum"], name: "index_ce_on_hbpbs2_cu_csn"
    t.index ["has_been_processed_by_stream_2"], name: "index_course_events_on_has_been_processed_by_stream_2"
  end

  create_table "course_states", force: :cascade do |t|
    t.uuid "course_uuid", null: false
    t.boolean "is_archived", null: false
  end

  create_table "protocol_records", force: :cascade do |t|
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

  create_table "stream1_bundle_entries", force: :cascade do |t|
    t.uuid "course_event_uuid", null: false
    t.uuid "stream1_bundle_uuid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "stream1_bundle_receipts", force: :cascade do |t|
    t.uuid "stream1_client_uuid", null: false
    t.uuid "stream1_bundle_uuid", null: false
    t.boolean "has_been_acknowledged", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "stream1_bundles", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.integer "seqnum", null: false
    t.uuid "course_uuid", null: false
    t.integer "course_event_seqnum_lo", null: false
    t.integer "course_event_seqnum_hi", null: false
    t.boolean "is_open", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "stream1_clients", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.boolean "is_prepped", null: false
    t.boolean "is_active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
