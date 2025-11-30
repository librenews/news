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

ActiveRecord::Schema[8.0].define(version: 2025_11_30_133939) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "article_chunks", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.integer "chunk_index", null: false
    t.text "text", null: false
    t.string "embedding_version"
    t.integer "token_count"
    t.string "checksum"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.vector "embedding_vector", limit: 384
    t.index ["article_id", "chunk_index"], name: "index_article_chunks_on_article_id_and_chunk_index", unique: true
    t.index ["article_id"], name: "index_article_chunks_on_article_id"
    t.index ["embedding_vector"], name: "index_article_chunks_on_embedding_vector", opclass: :vector_cosine_ops, using: :ivfflat
  end

  create_table "article_entities", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.bigint "entity_id", null: false
    t.integer "frequency", default: 1
    t.integer "sentence_positions", default: [], array: true
    t.float "confidence_score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id", "entity_id"], name: "index_article_entities_on_article_id_and_entity_id", unique: true
    t.index ["article_id"], name: "index_article_entities_on_article_id"
    t.index ["entity_id"], name: "index_article_entities_on_entity_id"
  end

  create_table "article_posts", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.bigint "post_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id", "post_id"], name: "index_article_posts_on_article_id_and_post_id", unique: true
    t.index ["article_id"], name: "index_article_posts_on_article_id"
    t.index ["post_id"], name: "index_article_posts_on_post_id"
  end

  create_table "articles", force: :cascade do |t|
    t.text "title", null: false
    t.text "url", null: false
    t.text "summary"
    t.datetime "published_at"
    t.text "author"
    t.text "description"
    t.text "image_url"
    t.text "html_content"
    t.text "body_text"
    t.jsonb "entities"
    t.jsonb "jsonld_data"
    t.jsonb "og_metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "cleaned_text"
    t.index ["url"], name: "index_articles_on_url", unique: true
  end

  create_table "entities", force: :cascade do |t|
    t.string "name", null: false
    t.string "entity_type", null: false
    t.string "normalized_name", null: false
    t.string "external_reference"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["normalized_name", "entity_type"], name: "index_entities_on_normalized_name_and_entity_type", unique: true
    t.index ["normalized_name"], name: "index_entities_on_normalized_name"
  end

  create_table "posts", force: :cascade do |t|
    t.bigint "source_id", null: false
    t.jsonb "post"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_id"], name: "index_posts_on_source_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "sources", force: :cascade do |t|
    t.text "atproto_did"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "profile", default: {}
    t.index ["atproto_did"], name: "index_sources_on_atproto_did", unique: true
    t.index ["profile"], name: "index_sources_on_profile", using: :gin
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
    t.jsonb "profile", default: {}
    t.index ["atproto_did"], name: "index_users_on_atproto_did", unique: true
    t.index ["profile"], name: "index_users_on_profile", using: :gin
  end

  add_foreign_key "article_chunks", "articles"
  add_foreign_key "article_entities", "articles"
  add_foreign_key "article_entities", "entities"
  add_foreign_key "article_posts", "articles"
  add_foreign_key "article_posts", "posts"
  add_foreign_key "posts", "sources"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "user_sources", "sources"
  add_foreign_key "user_sources", "users"
end
