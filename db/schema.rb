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

ActiveRecord::Schema[8.0].define(version: 2026_04_14_093917) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "ltree"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "document_nodes", force: :cascade do |t|
    t.bigint "legislation_version_id", null: false
    t.bigint "parent_id"
    t.ltree "tree_path"
    t.string "element_type"
    t.string "eid"
    t.string "num"
    t.string "heading"
    t.text "content_text"
    t.integer "position"
    t.integer "depth"
    t.tsvector "searchable"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["heading"], name: "index_document_nodes_on_heading_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["legislation_version_id", "eid"], name: "index_document_nodes_on_legislation_version_id_and_eid"
    t.index ["legislation_version_id"], name: "index_document_nodes_on_legislation_version_id"
    t.index ["parent_id"], name: "index_document_nodes_on_parent_id"
    t.index ["searchable"], name: "index_document_nodes_on_searchable", using: :gin
    t.index ["tree_path"], name: "index_document_nodes_on_tree_path", using: :gist
  end

  create_table "ingestion_logs", force: :cascade do |t|
    t.bigint "jurisdiction_id", null: false
    t.string "source_name"
    t.string "status", default: "running", null: false
    t.integer "documents_processed", default: 0
    t.string "last_etag"
    t.datetime "last_modified_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jurisdiction_id", "source_name", "created_at"], name: "idx_on_jurisdiction_id_source_name_created_at_da3acd94a6"
    t.index ["jurisdiction_id"], name: "index_ingestion_logs_on_jurisdiction_id"
  end

  create_table "jurisdictions", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.string "jurisdiction_type"
    t.jsonb "api_config", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_jurisdictions_on_code", unique: true
  end

  create_table "legislation_version_contents", force: :cascade do |t|
    t.bigint "legislation_version_id", null: false
    t.text "raw_xml"
    t.text "raw_html"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["legislation_version_id"], name: "index_legislation_version_contents_on_legislation_version_id", unique: true
  end

  create_table "legislation_versions", force: :cascade do |t|
    t.bigint "legislation_id", null: false
    t.string "version_uri", null: false
    t.string "language", default: "en"
    t.date "valid_from"
    t.date "valid_to"
    t.date "publication_date"
    t.string "version_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["legislation_id"], name: "index_legislation_versions_on_legislation_id"
    t.index ["valid_from", "valid_to"], name: "index_legislation_versions_on_valid_from_and_valid_to"
    t.index ["version_uri"], name: "index_legislation_versions_on_version_uri", unique: true
  end

  create_table "legislations", force: :cascade do |t|
    t.bigint "jurisdiction_id", null: false
    t.string "frbr_uri", null: false
    t.string "celex_number"
    t.string "eli_uri"
    t.string "title", null: false
    t.string "legislation_type"
    t.integer "year"
    t.string "status"
    t.string "source_identifier"
    t.string "content_hash"
    t.tsvector "searchable"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["celex_number"], name: "index_legislations_on_celex_number"
    t.index ["eli_uri"], name: "index_legislations_on_eli_uri"
    t.index ["frbr_uri"], name: "index_legislations_on_frbr_uri", unique: true
    t.index ["jurisdiction_id"], name: "index_legislations_on_jurisdiction_id"
    t.index ["searchable"], name: "index_legislations_on_searchable", using: :gin
    t.index ["status"], name: "index_legislations_on_status"
    t.index ["title"], name: "index_legislations_on_title_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "alert_frequency", default: "daily", null: false
    t.boolean "alert_email_enabled", default: true, null: false
    t.datetime "last_digest_sent_at"
    t.string "api_token"
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "watchlist_items", force: :cascade do |t|
    t.bigint "watchlist_id", null: false
    t.bigint "legislation_id"
    t.bigint "jurisdiction_id"
    t.string "legislation_type"
    t.string "item_type", default: "specific_legislation", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jurisdiction_id"], name: "index_watchlist_items_on_jurisdiction_id"
    t.index ["legislation_id"], name: "index_watchlist_items_on_legislation_id"
    t.index ["watchlist_id", "legislation_id"], name: "idx_watchlist_items_unique_legislation", unique: true, where: "(legislation_id IS NOT NULL)"
    t.index ["watchlist_id"], name: "index_watchlist_items_on_watchlist_id"
  end

  create_table "watchlists", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", default: "My Watchlist", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], name: "index_watchlists_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_watchlists_on_user_id"
  end

  add_foreign_key "document_nodes", "document_nodes", column: "parent_id"
  add_foreign_key "document_nodes", "legislation_versions"
  add_foreign_key "ingestion_logs", "jurisdictions"
  add_foreign_key "legislation_version_contents", "legislation_versions"
  add_foreign_key "legislation_versions", "legislations"
  add_foreign_key "legislations", "jurisdictions"
  add_foreign_key "sessions", "users"
  add_foreign_key "watchlist_items", "jurisdictions"
  add_foreign_key "watchlist_items", "legislations"
  add_foreign_key "watchlist_items", "watchlists"
  add_foreign_key "watchlists", "users"
end
