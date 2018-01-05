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

ActiveRecord::Schema.define(version: 20171031115929) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "autoscaling_requests", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "group_uuid", null: false
    t.string "request_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "calc_requests", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.integer "partition_value", null: false
    t.uuid "ecosystem_uuid", null: false
    t.uuid "learner_uuid", null: false
    t.boolean "has_been_processed", null: false
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_calc_requests_on_created_at"
    t.index ["has_been_processed"], name: "index_calc_requests_on_has_been_processed"
    t.index ["learner_uuid", "ecosystem_uuid"], name: "index_calc_requests_on_learner_uuid_and_ecosystem_uuid"
    t.index ["learner_uuid"], name: "index_calc_requests_on_learner_uuid"
    t.index ["uuid"], name: "index_calc_requests_on_uuid", unique: true
  end

  create_table "calc_results", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "calc_request_uuid", null: false
    t.integer "partition_value", null: false
    t.uuid "ecosystem_uuid", null: false
    t.uuid "learner_uuid", null: false
    t.boolean "has_been_reported", null: false
    t.datetime "reported_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calc_request_uuid"], name: "index_calc_results_on_calc_request_uuid", unique: true
    t.index ["created_at"], name: "index_calc_results_on_created_at"
    t.index ["has_been_reported"], name: "index_calc_results_on_has_been_reported"
    t.index ["uuid"], name: "index_calc_results_on_uuid", unique: true
  end

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

  create_table "learner_responses", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.uuid "ecosystem_uuid", null: false
    t.uuid "learner_uuid", null: false
    t.uuid "question_uuid", null: false
    t.uuid "trial_uuid", null: false
    t.boolean "was_correct", null: false
    t.datetime "responded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_learner_responses_on_created_at"
    t.index ["learner_uuid"], name: "index_learner_responses_on_learner_uuid"
    t.index ["question_uuid"], name: "index_learner_responses_on_question_uuid"
    t.index ["uuid"], name: "index_learner_responses_on_uuid", unique: true
  end

  create_table "protocol_records", force: :cascade do |t|
    t.uuid "group_uuid", null: false
    t.uuid "instance_uuid", null: false
    t.integer "instance_count", null: false
    t.integer "instance_modulo", null: false
    t.string "instance_desc", null: false
    t.uuid "boss_uuid", null: false
    t.datetime "next_end_time", null: false
    t.datetime "next_boss_time", null: false
    t.datetime "next_work_time", null: false
    t.datetime "next_wake_time", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_uuid", "instance_modulo"], name: "index_protocol_records_on_group_uuid_and_instance_modulo", unique: true
    t.index ["group_uuid"], name: "index_protocol_records_on_group_uuid"
    t.index ["instance_uuid"], name: "index_protocol_records_on_instance_uuid", unique: true
  end

end
