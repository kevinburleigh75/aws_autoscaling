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

ActiveRecord::Schema.define(version: 20171203135751) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "course_event_states", force: :cascade do |t|
    t.uuid "course_uuid", null: false
    t.integer "last_course_seqnum", null: false
    t.boolean "needs_attention", null: false
    t.datetime "waiting_since", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_uuid"], name: "index_course_event_states_on_course_uuid", unique: true
    t.index ["needs_attention", "waiting_since"], name: "index_course_event_states_on_needs_attention_and_waiting_since"
    t.index ["needs_attention"], name: "index_course_event_states_on_needs_attention"
    t.index ["waiting_since"], name: "index_course_event_states_on_waiting_since"
  end

  create_table "course_events", force: :cascade do |t|
    t.uuid "course_uuid", null: false
    t.integer "course_seqnum", null: false
    t.string "event_type", null: false
    t.uuid "event_uuid", null: false
    t.datetime "event_time", null: false
    t.integer "partition_value", null: false
    t.boolean "has_been_processed_by_stream1", null: false
    t.boolean "has_been_processed_by_stream2", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_uuid", "course_seqnum"], name: "index_course_events_on_course_uuid_and_course_seqnum", unique: true
    t.index ["course_uuid", "has_been_processed_by_stream1", "course_seqnum"], name: "index_ces_on_cu_hbpbs1_csn"
    t.index ["course_uuid"], name: "index_course_events_on_course_uuid"
    t.index ["event_uuid", "has_been_processed_by_stream1", "course_seqnum"], name: "index_ces_on_eu_hbpbs1_csn"
    t.index ["event_uuid"], name: "index_course_events_on_event_uuid", unique: true
    t.index ["has_been_processed_by_stream1", "course_uuid", "course_seqnum"], name: "index_ce_on_hbpbs1_cu_csn"
    t.index ["has_been_processed_by_stream1"], name: "index_course_events_on_has_been_processed_by_stream1"
  end

  create_table "protocol_records", force: :cascade do |t|
    t.uuid "group_uuid", null: false
    t.string "group_desc", null: false
    t.uuid "instance_uuid", null: false
    t.string "instance_desc", null: false
    t.integer "instance_count", null: false
    t.integer "instance_modulo", null: false
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

  create_table "stream1_bundle_entries", force: :cascade do |t|
    t.uuid "course_event_uuid", null: false
    t.uuid "stream_bundle_uuid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_event_uuid"], name: "index_stream1_bundle_entries_on_course_event_uuid", unique: true
    t.index ["stream_bundle_uuid"], name: "index_stream1_bundle_entries_on_stream_bundle_uuid"
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
    t.uuid "course_uuid", null: false
    t.integer "course_event_seqnum_lo", null: false
    t.integer "course_event_seqnum_hi", null: false
    t.integer "size", null: false
    t.boolean "is_open", null: false
    t.boolean "has_been_processed", null: false
    t.datetime "waiting_since", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_event_seqnum_hi"], name: "index_stream1_bundles_on_course_event_seqnum_hi"
    t.index ["course_event_seqnum_lo"], name: "index_stream1_bundles_on_course_event_seqnum_lo"
    t.index ["course_uuid", "course_event_seqnum_hi"], name: "index_s1bs_on_cu_cesh", unique: true
    t.index ["course_uuid", "course_event_seqnum_lo", "course_event_seqnum_hi"], name: "index_s1bs_on_cu_cesl_cesh"
    t.index ["course_uuid", "course_event_seqnum_lo"], name: "index_s1bs_on_cu_cesl", unique: true
    t.index ["course_uuid"], name: "index_stream1_bundles_on_course_uuid"
    t.index ["has_been_processed"], name: "index_stream1_bundles_on_has_been_processed"
    t.index ["uuid"], name: "index_stream1_bundles_on_uuid", unique: true
    t.index ["waiting_since"], name: "index_stream1_bundles_on_waiting_since"
  end

  create_table "stream1_client_states", force: :cascade do |t|
    t.uuid "client_uuid", null: false
    t.uuid "course_uuid", null: false
    t.integer "last_confirmed_course_seqnum", null: false
    t.boolean "needs_attention", null: false
    t.datetime "waiting_since", null: false
    t.index ["client_uuid", "course_uuid", "last_confirmed_course_seqnum"], name: "index_s1css_on_cu_cu_lccs"
    t.index ["client_uuid", "course_uuid"], name: "index_s1css_on_cu_cu", unique: true
    t.index ["client_uuid"], name: "index_stream1_client_states_on_client_uuid"
    t.index ["course_uuid"], name: "index_stream1_client_states_on_course_uuid"
    t.index ["needs_attention", "client_uuid", "course_uuid"], name: "index_s1css_on_na_cu_cu"
    t.index ["needs_attention"], name: "index_stream1_client_states_on_needs_attention"
    t.index ["waiting_since"], name: "index_stream1_client_states_on_waiting_since"
  end

  create_table "stream1_clients", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_stream1_clients_on_name", unique: true
    t.index ["uuid"], name: "index_stream1_clients_on_uuid", unique: true
  end

  create_table "stream1_course_bundle_states", force: :cascade do |t|
    t.uuid "course_uuid", null: false
    t.boolean "needs_attention", null: false
    t.datetime "waiting_since", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_uuid"], name: "index_stream1_course_bundle_states_on_course_uuid", unique: true
    t.index ["needs_attention", "waiting_since"], name: "index_s1cbss_on_na_ws"
    t.index ["needs_attention"], name: "index_stream1_course_bundle_states_on_needs_attention"
    t.index ["waiting_since"], name: "index_stream1_course_bundle_states_on_waiting_since"
  end

end
