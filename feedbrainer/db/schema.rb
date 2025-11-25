# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_11_25_131500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "sources", force: :cascade do |t|
    t.text "atproto_did"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["atproto_did"], name: "index_sources_on_atproto_did", unique: true
  end

  create_table "user_sources", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "source_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_id"], name: "index_user_sources_on_source_id"
    t.index ["user_id", "source_id"], name: "index_user_sources_on_user_id_and_source_id", unique: true
    t.index ["user_id"], name: "index_user_sources_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.text "atproto_did"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["atproto_did"], name: "index_users_on_atproto_did", unique: true
  end

  add_foreign_key "user_sources", "sources"
  add_foreign_key "user_sources", "users"
end
