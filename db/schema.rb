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

ActiveRecord::Schema[8.0].define(version: 2026_04_12_000005) do
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
    t.index ["legislation_version_id", "eid"], name: "index_document_nodes_on_legislation_version_id_and_eid"
    t.index ["legislation_version_id"], name: "index_document_nodes_on_legislation_version_id"
    t.index ["parent_id"], name: "index_document_nodes_on_parent_id"
    t.index ["searchable"], name: "index_document_nodes_on_searchable", using: :gin
    t.index ["tree_path"], name: "index_document_nodes_on_tree_path", using: :gist
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

  create_table "legislation_versions", force: :cascade do |t|
    t.bigint "legislation_id", null: false
    t.string "version_uri", null: false
    t.string "language", default: "en"
    t.date "valid_from"
    t.date "valid_to"
    t.date "publication_date"
    t.string "version_type"
    t.text "raw_xml"
    t.text "raw_html"
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
    t.index ["frbr_uri"], name: "index_legislations_on_frbr_uri", unique: true
    t.index ["jurisdiction_id"], name: "index_legislations_on_jurisdiction_id"
    t.index ["searchable"], name: "index_legislations_on_searchable", using: :gin
  end

  add_foreign_key "document_nodes", "document_nodes", column: "parent_id"
  add_foreign_key "document_nodes", "legislation_versions"
  add_foreign_key "legislation_versions", "legislations"
  add_foreign_key "legislations", "jurisdictions"
end
