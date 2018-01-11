# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20160311184754) do

  create_table "batch_submissions", force: :cascade do |t|
    t.integer  "batch_id",      limit: 4
    t.integer  "submission_id", limit: 4
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  add_index "batch_submissions", ["batch_id"], name: "index_batch_submissions_on_batch_id", using: :btree
  add_index "batch_submissions", ["submission_id"], name: "index_batch_submissions_on_submission_id", using: :btree

  create_table "batches", force: :cascade do |t|
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.string   "batch_id",   limit: 255
    t.integer  "seq_count",  limit: 4
  end

  create_table "submissions", force: :cascade do |t|
    t.string   "accession",             limit: 255
    t.string   "gi",                    limit: 255
    t.string   "category",              limit: 255
    t.string   "status",                limit: 255
    t.string   "job_id",                limit: 255
    t.string   "sidekiq_id",            limit: 255
    t.integer  "runtime",               limit: 4
    t.text     "error",                 limit: 65535
    t.string   "sequence_type",         limit: 255
    t.string   "sequence_file_name",    limit: 255
    t.string   "sequence_content_type", limit: 255
    t.integer  "sequence_file_size",    limit: 4
    t.datetime "sequence_updated_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "sequence_length",       limit: 4
    t.integer  "phage_found",           limit: 4
    t.string   "description",           limit: 255
    t.decimal  "adenine_count",                       precision: 10
    t.decimal  "guanine_count",                       precision: 10
    t.decimal  "thymine_count",                       precision: 10
    t.decimal  "cytosine_count",                      precision: 10
    t.boolean  "contigs",               limit: 1,                    default: false
  end

  add_foreign_key "batch_submissions", "batches"
  add_foreign_key "batch_submissions", "submissions"
end
