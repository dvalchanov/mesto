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

ActiveRecord::Schema[8.1].define(version: 2026_09_04_183000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "postgis"

  create_table "administrative_act_references", force: :cascade do |t|
    t.bigint "administrative_act_id", null: false
    t.string "cadastral_identifier", null: false
    t.datetime "created_at", null: false
    t.string "match_basis"
    t.string "reference_level", null: false
    t.datetime "updated_at", null: false
    t.index ["administrative_act_id", "cadastral_identifier"], name: "idx_act_refs_on_act_and_identifier", unique: true
    t.index ["administrative_act_id"], name: "index_administrative_act_references_on_administrative_act_id"
    t.index ["cadastral_identifier"], name: "index_administrative_act_references_on_cadastral_identifier"
  end

  create_table "administrative_acts", force: :cascade do |t|
    t.string "act_number"
    t.string "address"
    t.decimal "built_up_area", precision: 14, scale: 2
    t.string "construction_category"
    t.datetime "created_at", null: false
    t.string "district"
    t.string "document_url"
    t.date "effective_on"
    t.string "external_key", null: false
    t.geometry "geometry", limit: {srid: 4326, type: "geometry"}
    t.decimal "gross_floor_area", precision: 14, scale: 2
    t.date "issued_on"
    t.string "issuer"
    t.string "locality"
    t.text "object_description"
    t.jsonb "properties", default: {}, null: false
    t.string "registry_kind", null: false
    t.string "source_url", null: false
    t.string "status"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "upi"
    t.index ["geometry"], name: "index_administrative_acts_on_geometry", using: :gist
    t.index ["registry_kind", "external_key"], name: "index_administrative_acts_on_registry_kind_and_external_key", unique: true
  end

  create_table "buyer_journeys", force: :cascade do |t|
    t.string "buyer_stage", default: "researching", null: false
    t.datetime "created_at", null: false
    t.string "financing_context"
    t.string "guest_identity_digest", null: false
    t.string "label"
    t.datetime "last_active_at", null: false
    t.datetime "onboarding_completed_at"
    t.bigint "property_analysis_id"
    t.string "property_type", default: "undecided", null: false
    t.uuid "public_token", default: -> { "gen_random_uuid()" }, null: false
    t.datetime "updated_at", null: false
    t.string "user_reported_building_stage"
    t.index ["guest_identity_digest", "last_active_at"], name: "idx_on_guest_identity_digest_last_active_at_59d85c6739"
    t.index ["property_analysis_id"], name: "index_buyer_journeys_on_property_analysis_id"
    t.index ["public_token"], name: "index_buyer_journeys_on_public_token", unique: true
  end

  create_table "cadastral_properties", force: :cascade do |t|
    t.text "additional_parts"
    t.string "address"
    t.string "address_floor"
    t.decimal "area_sqm", precision: 14, scale: 2
    t.string "block_number"
    t.string "cadastral_identifier", null: false
    t.string "category_type"
    t.datetime "created_at", null: false
    t.string "district"
    t.string "entrance"
    t.string "floor"
    t.integer "floors_count"
    t.geometry "geometry", limit: {srid: 4326, type: "geometry"}
    t.string "identifier_level", null: false
    t.integer "levels_count"
    t.string "locality"
    t.string "object_number"
    t.integer "objects_count"
    t.string "old_identifier"
    t.decimal "outline_area_sqm", precision: 14, scale: 2
    t.string "ownership_code"
    t.string "ownership_type"
    t.decimal "perimeter_m", precision: 14, scale: 2
    t.string "permanent_use"
    t.string "permanent_use_code"
    t.string "place"
    t.jsonb "properties", default: {}, null: false
    t.string "purpose"
    t.string "purpose_code"
    t.string "quarter"
    t.string "regulation_parcel"
    t.string "settlement_name"
    t.string "source_archive_key", null: false
    t.geometry "source_geometry", limit: {srid: 7801, type: "geometry"}
    t.datetime "source_relevant_at"
    t.string "source_url", null: false
    t.string "street_name"
    t.string "street_number"
    t.string "territory_code"
    t.string "territory_type"
    t.datetime "updated_at", null: false
    t.text "validation_document"
    t.index ["cadastral_identifier"], name: "index_cadastral_properties_on_cadastral_identifier", unique: true
    t.index ["geometry"], name: "index_cadastral_properties_on_geometry", using: :gist
    t.index ["identifier_level", "cadastral_identifier"], name: "idx_cadastral_properties_hierarchy"
    t.index ["source_archive_key"], name: "index_cadastral_properties_on_source_archive_key"
    t.index ["source_geometry"], name: "index_cadastral_properties_on_source_geometry", using: :gist
  end

  create_table "cadastre_imports", force: :cascade do |t|
    t.string "checksum"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "importer_version", default: 1, null: false
    t.integer "records_imported", default: 0, null: false
    t.integer "records_seen", default: 0, null: false
    t.datetime "relevant_at"
    t.string "source_archive_key", null: false
    t.string "source_url", null: false
    t.datetime "started_at"
    t.string "status", default: "running", null: false
    t.datetime "updated_at", null: false
    t.index ["source_archive_key", "checksum"], name: "index_cadastre_imports_on_source_archive_key_and_checksum", unique: true
    t.index ["source_archive_key", "status"], name: "index_cadastre_imports_on_source_archive_key_and_status"
  end

  create_table "dataset_imports", force: :cascade do |t|
    t.string "checksum"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "records_created", default: 0, null: false
    t.integer "records_removed", default: 0, null: false
    t.integer "records_seen", default: 0, null: false
    t.integer "records_updated", default: 0, null: false
    t.bigint "spatial_dataset_id", null: false
    t.datetime "started_at"
    t.string "status", default: "running", null: false
    t.datetime "updated_at", null: false
    t.index ["spatial_dataset_id"], name: "index_dataset_imports_on_spatial_dataset_id"
  end

  create_table "journey_item_progresses", force: :cascade do |t|
    t.bigint "buyer_journey_id", null: false
    t.integer "content_version", default: 1, null: false
    t.datetime "created_at", null: false
    t.string "item_key", null: false
    t.string "item_kind", null: false
    t.datetime "marked_at"
    t.string "status", default: "not_started", null: false
    t.datetime "updated_at", null: false
    t.index ["buyer_journey_id", "item_key", "item_kind"], name: "idx_journey_progress_unique_item", unique: true
    t.index ["buyer_journey_id"], name: "index_journey_item_progresses_on_buyer_journey_id"
  end

  create_table "orders", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.string "email", null: false
    t.datetime "failed_at"
    t.datetime "paid_at"
    t.string "payment_provider", null: false
    t.string "product_code", null: false
    t.bigint "property_analysis_id", null: false
    t.string "provider_reference"
    t.uuid "public_token", default: -> { "gen_random_uuid()" }, null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["property_analysis_id", "status"], name: "index_orders_on_property_analysis_id_and_status"
    t.index ["property_analysis_id"], name: "index_orders_on_property_analysis_id"
    t.index ["provider_reference"], name: "index_orders_on_provider_reference", unique: true, where: "(provider_reference IS NOT NULL)"
    t.index ["public_token"], name: "index_orders_on_public_token", unique: true
  end

  create_table "product_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.datetime "occurred_at", null: false
    t.bigint "order_id"
    t.bigint "property_analysis_id"
    t.datetime "updated_at", null: false
    t.index ["name", "occurred_at"], name: "index_product_events_on_name_and_occurred_at"
    t.index ["order_id"], name: "index_product_events_on_order_id"
    t.index ["property_analysis_id"], name: "index_product_events_on_property_analysis_id"
  end

  create_table "property_analyses", force: :cascade do |t|
    t.string "building_identifier"
    t.geography "centroid", limit: {srid: 4326, type: "st_point", geographic: true}
    t.datetime "completed_at"
    t.string "coverage_status", default: "limited", null: false
    t.datetime "created_at", null: false
    t.datetime "failed_at"
    t.text "failure_message"
    t.string "identifier_level", null: false
    t.string "individual_object_identifier"
    t.string "location_precision", default: "unavailable", null: false
    t.jsonb "metrics", default: {}, null: false
    t.geometry "parcel_geometry", limit: {srid: 4326, type: "multi_polygon"}
    t.string "parcel_identifier", null: false
    t.uuid "public_token", default: -> { "gen_random_uuid()" }, null: false
    t.string "settlement_code", null: false
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.string "submitted_identifier", null: false
    t.jsonb "summary", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["centroid"], name: "index_property_analyses_on_centroid", using: :gist
    t.index ["parcel_geometry"], name: "index_property_analyses_on_parcel_geometry", using: :gist
    t.index ["public_token"], name: "index_property_analyses_on_public_token", unique: true
    t.index ["submitted_identifier", "completed_at"], name: "idx_on_submitted_identifier_completed_at_29246503d7"
  end

  create_table "source_runs", force: :cascade do |t|
    t.string "checksum"
    t.datetime "created_at", null: false
    t.string "error_class"
    t.text "error_message"
    t.datetime "fetched_at"
    t.jsonb "parsed_payload", default: {}, null: false
    t.bigint "property_analysis_id", null: false
    t.text "raw_response"
    t.datetime "relevant_at"
    t.jsonb "request_metadata", default: {}, null: false
    t.string "source_key", null: false
    t.string "source_url"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["property_analysis_id", "source_key"], name: "index_source_runs_on_property_analysis_id_and_source_key"
    t.index ["property_analysis_id"], name: "index_source_runs_on_property_analysis_id"
  end

  create_table "spatial_datasets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_dataset_id"
    t.string "key", null: false
    t.datetime "last_imported_at"
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.string "provider", null: false
    t.datetime "relevant_at"
    t.string "source_url", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_spatial_datasets_on_key", unique: true
  end

  create_table "spatial_features", force: :cascade do |t|
    t.string "address"
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "external_key", null: false
    t.geometry "geometry", limit: {srid: 4326, type: "geometry"}, null: false
    t.string "name"
    t.jsonb "properties", default: {}, null: false
    t.bigint "spatial_dataset_id", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_spatial_features_on_category"
    t.index ["geometry"], name: "index_spatial_features_on_geometry", using: :gist
    t.index ["spatial_dataset_id", "external_key"], name: "index_spatial_features_on_spatial_dataset_id_and_external_key", unique: true
    t.index ["spatial_dataset_id"], name: "index_spatial_features_on_spatial_dataset_id"
  end

  add_foreign_key "administrative_act_references", "administrative_acts"
  add_foreign_key "buyer_journeys", "property_analyses"
  add_foreign_key "dataset_imports", "spatial_datasets"
  add_foreign_key "journey_item_progresses", "buyer_journeys"
  add_foreign_key "orders", "property_analyses"
  add_foreign_key "product_events", "orders"
  add_foreign_key "product_events", "property_analyses"
  add_foreign_key "source_runs", "property_analyses"
  add_foreign_key "spatial_features", "spatial_datasets"
end
