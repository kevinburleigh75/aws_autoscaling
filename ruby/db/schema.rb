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

ActiveRecord::Schema.define(version: 20180513071236) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "autoscaling_requests", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "group_uuid", null: false
    t.string "request_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "desired_capacity", null: false
  end

  create_table "bundle_buckets", force: :cascade do |t|
    t.uuid "bucket_uuid", null: false
    t.integer "bucket_num", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bucket_num"], name: "index_bundle_buckets_on_bucket_num", unique: true
    t.index ["bucket_uuid"], name: "index_bundle_buckets_on_bucket_uuid", unique: true
  end

  create_table "bundle_course_indicators", force: :cascade do |t|
    t.uuid "indicator_uuid", null: false
    t.uuid "course_uuid", null: false
    t.string "source", null: false
    t.boolean "has_been_processed", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_uuid", "has_been_processed", "created_at"], name: "index_bcis_on_cu_hbp_ca"
    t.index ["created_at", "has_been_processed"], name: "index_bcis_on_ca_hbp"
    t.index ["has_been_processed", "course_uuid", "created_at"], name: "index_bcis_on_hbp_cu_ca"
    t.index ["indicator_uuid"], name: "index_bundle_course_indicators_on_indicator_uuid", unique: true
  end

  create_table "course_buckets", force: :cascade do |t|
    t.uuid "course_uuid", null: false
    t.integer "bucket_num", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bucket_num", "course_uuid"], name: "index_course_buckets_on_bucket_num_and_course_uuid"
    t.index ["course_uuid"], name: "index_course_buckets_on_course_uuid", unique: true
  end

  create_table "course_bundle_entries", force: :cascade do |t|
    t.uuid "course_event_uuid", null: false
    t.uuid "course_bundle_uuid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_bundle_uuid"], name: "index_course_bundle_entries_on_course_bundle_uuid"
    t.index ["course_event_uuid"], name: "index_course_bundle_entries_on_course_event_uuid", unique: true
  end

  create_table "course_bundle_states", force: :cascade do |t|
    t.uuid "course_uuid", null: false
    t.boolean "needs_attention", null: false
    t.datetime "waiting_since", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_uuid"], name: "index_course_bundle_states_on_course_uuid", unique: true
    t.index ["needs_attention", "waiting_since"], name: "index_cbss_on_na_ws"
    t.index ["needs_attention"], name: "index_course_bundle_states_on_needs_attention"
    t.index ["waiting_since"], name: "index_course_bundle_states_on_waiting_since"
  end

  create_table "course_bundles", force: :cascade do |t|
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
    t.index ["course_event_seqnum_hi"], name: "index_course_bundles_on_course_event_seqnum_hi"
    t.index ["course_event_seqnum_lo"], name: "index_course_bundles_on_course_event_seqnum_lo"
    t.index ["course_uuid", "course_event_seqnum_hi"], name: "index_cbs_on_cu_cesh", unique: true
    t.index ["course_uuid", "course_event_seqnum_lo", "course_event_seqnum_hi"], name: "index_cbs_on_cu_cesl_cesh"
    t.index ["course_uuid", "course_event_seqnum_lo"], name: "index_cbs_on_cu_cesl", unique: true
    t.index ["course_uuid"], name: "index_course_bundles_on_course_uuid"
    t.index ["has_been_processed"], name: "index_course_bundles_on_has_been_processed"
    t.index ["uuid"], name: "index_course_bundles_on_uuid", unique: true
    t.index ["waiting_since"], name: "index_course_bundles_on_waiting_since"
  end

  create_table "course_client_states", force: :cascade do |t|
    t.uuid "client_uuid", null: false
    t.uuid "course_uuid", null: false
    t.integer "last_confirmed_course_seqnum", null: false
    t.boolean "needs_attention", null: false
    t.datetime "waiting_since", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_uuid", "course_uuid", "last_confirmed_course_seqnum"], name: "index_ccss_on_cu_cu_lccs"
    t.index ["client_uuid", "course_uuid"], name: "index_ccss_on_cu_cu", unique: true
    t.index ["client_uuid"], name: "index_course_client_states_on_client_uuid"
    t.index ["course_uuid"], name: "index_course_client_states_on_course_uuid"
    t.index ["needs_attention", "client_uuid", "course_uuid"], name: "index_ccss_on_na_cu_cu"
    t.index ["needs_attention"], name: "index_course_client_states_on_needs_attention"
    t.index ["waiting_since"], name: "index_course_client_states_on_waiting_since"
  end

  create_table "course_clients", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_course_clients_on_name", unique: true
    t.index ["uuid"], name: "index_course_clients_on_uuid", unique: true
  end

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
    t.boolean "has_been_bundled", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_uuid", "course_seqnum"], name: "index_course_events_on_course_uuid_and_course_seqnum", unique: true
    t.index ["course_uuid", "has_been_bundled", "course_seqnum"], name: "index_ces_on_cu_hbb_csn"
    t.index ["course_uuid"], name: "index_course_events_on_course_uuid"
    t.index ["event_uuid", "has_been_bundled", "course_seqnum"], name: "index_ces_on_eu_hbb_csn"
    t.index ["event_uuid"], name: "index_course_events_on_event_uuid", unique: true
    t.index ["has_been_bundled", "course_uuid", "course_seqnum"], name: "index_ce_on_hbb_cu_csn"
    t.index ["has_been_bundled"], name: "index_course_events_on_has_been_bundled"
  end

  create_table "health_check_events", force: :cascade do |t|
    t.uuid "health_check_uuid", null: false
    t.string "instance_id", null: false
    t.string "health_status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_health_check_events_on_created_at"
    t.index ["health_check_uuid"], name: "index_health_check_events_on_health_check_uuid", unique: true
    t.index ["health_status"], name: "index_health_check_events_on_health_status"
    t.index ["instance_id"], name: "index_health_check_events_on_instance_id"
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
