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

ActiveRecord::Schema[8.0].define(version: 2025_11_29_161020) do
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

  add_foreign_key "article_chunks", "articles"
  add_foreign_key "article_entities", "articles"
  add_foreign_key "article_entities", "entities"
  add_foreign_key "article_posts", "articles"
  add_foreign_key "article_posts", "posts"
  add_foreign_key "posts", "sources"
  add_foreign_key "user_sources", "sources"
  add_foreign_key "user_sources", "users"
end
