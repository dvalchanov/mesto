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

ActiveRecord::Schema[8.1].define(version: 2026_09_20_170000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
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

  create_table "analysis_revisions", force: :cascade do |t|
    t.integer "calculation_version", default: 1, null: false
    t.datetime "completed_at"
    t.string "coverage_profile_key", null: false
    t.datetime "created_at", null: false
    t.jsonb "dataset_revisions", default: {}, null: false
    t.text "error_message"
    t.jsonb "geometry_bases", default: {}, null: false
    t.integer "number", null: false
    t.bigint "property_analysis_id", null: false
    t.jsonb "report_snapshot", default: {}, null: false
    t.datetime "started_at"
    t.string "status", default: "running", null: false
    t.datetime "updated_at", null: false
    t.index ["property_analysis_id", "number"], name: "index_analysis_revisions_on_property_analysis_id_and_number", unique: true
    t.index ["property_analysis_id"], name: "index_analysis_revisions_on_property_analysis_id"
  end

  create_table "budget_scenarios", force: :cascade do |t|
    t.bigint "buyer_journey_id"
    t.datetime "calculated_at", null: false
    t.jsonb "calculation_snapshot", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "EUR", null: false
    t.string "engine_version", null: false
    t.jsonb "financial_rule_versions", default: {}, null: false
    t.string "guest_identity_digest", null: false
    t.integer "input_schema_version", default: 1, null: false
    t.bigint "property_analysis_id"
    t.uuid "public_token", default: -> { "gen_random_uuid()" }, null: false
    t.string "title", default: "Моята сметка", null: false
    t.datetime "updated_at", null: false
    t.jsonb "validated_inputs", default: {}, null: false
    t.index ["buyer_journey_id"], name: "index_budget_scenarios_on_buyer_journey_id"
    t.index ["guest_identity_digest", "updated_at"], name: "index_budget_scenarios_on_guest_identity_digest_and_updated_at"
    t.index ["property_analysis_id"], name: "index_budget_scenarios_on_property_analysis_id"
    t.index ["public_token"], name: "index_budget_scenarios_on_public_token", unique: true
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
    t.index "lower((address)::text) gin_trgm_ops", name: "idx_cadastral_buildings_address_search", where: "(((identifier_level)::text = 'building'::text) AND (address IS NOT NULL))", using: :gin
    t.index "lower((address)::text) gin_trgm_ops", name: "idx_cadastral_properties_address_search", where: "(((identifier_level)::text = 'individual_object'::text) AND (address IS NOT NULL))", using: :gin
    t.index ["cadastral_identifier"], name: "index_cadastral_properties_on_cadastral_identifier", unique: true
    t.index ["geometry"], name: "index_cadastral_properties_on_geometry", using: :gist
    t.index ["identifier_level", "cadastral_identifier"], name: "idx_cadastral_properties_hierarchy"
    t.index ["source_archive_key"], name: "index_cadastral_properties_on_source_archive_key"
    t.index ["source_geometry"], name: "index_cadastral_properties_on_source_geometry", using: :gist
  end

  create_table "cadastre_imports", force: :cascade do |t|
    t.string "checksum"
    t.datetime "completed_at"
    t.string "coverage_profile_key", default: "legacy", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "importer_version", default: 1, null: false
    t.jsonb "outcome_counts", default: {}, null: false
    t.integer "records_imported", default: 0, null: false
    t.integer "records_seen", default: 0, null: false
    t.datetime "relevant_at"
    t.string "scope_digest", default: "unscoped", null: false
    t.string "source_archive_key", null: false
    t.datetime "source_checked_at"
    t.string "source_checksum"
    t.string "source_etag"
    t.datetime "source_last_modified_at"
    t.string "source_url", null: false
    t.datetime "started_at"
    t.string "status", default: "running", null: false
    t.datetime "updated_at", null: false
    t.jsonb "validation_errors", default: {}, null: false
    t.index ["source_archive_key", "source_checksum", "importer_version", "scope_digest"], name: "idx_cadastre_imports_source_version_scope", unique: true, where: "(source_checksum IS NOT NULL)"
    t.index ["source_archive_key", "status"], name: "index_cadastre_imports_on_source_archive_key_and_status"
  end

  create_table "cadastre_rights", force: :cascade do |t|
    t.string "cadastral_identifier", null: false
    t.datetime "created_at", null: false
    t.string "document_code"
    t.text "document_description"
    t.text "document_note"
    t.string "document_type"
    t.string "holder_entity_type", null: false
    t.string "holder_identifier"
    t.string "holder_name", null: false
    t.text "holder_note"
    t.string "holder_type", null: false
    t.string "holder_type_code"
    t.string "identifier_level", null: false
    t.string "property_type"
    t.string "record_fingerprint", null: false
    t.string "right_code"
    t.text "right_description"
    t.string "right_type", null: false
    t.string "source_archive_key", null: false
    t.datetime "source_relevant_at"
    t.text "source_url", null: false
    t.datetime "updated_at", null: false
    t.index ["cadastral_identifier"], name: "index_cadastre_rights_on_cadastral_identifier"
    t.index ["holder_entity_type", "holder_name"], name: "index_cadastre_rights_on_holder_entity_type_and_holder_name"
    t.index ["holder_identifier"], name: "index_cadastre_rights_on_holder_identifier"
    t.index ["record_fingerprint"], name: "index_cadastre_rights_on_record_fingerprint", unique: true
    t.index ["source_archive_key"], name: "index_cadastre_rights_on_source_archive_key"
  end

  create_table "cadastre_source_archives", force: :cascade do |t|
    t.text "attribution"
    t.geometry "coverage_geometry", limit: {srid: 4326, type: "geometry"}
    t.string "coverage_profile_key", null: false
    t.datetime "created_at", null: false
    t.datetime "discovered_at"
    t.string "district", null: false
    t.boolean "enabled", default: false, null: false
    t.datetime "last_checked_at"
    t.bigint "latest_successful_import_id"
    t.jsonb "metadata", default: {}, null: false
    t.string "object_kind", null: false
    t.text "permission_reference"
    t.string "permission_status", default: "review_required", null: false
    t.string "source_archive_key", null: false
    t.string "source_url", null: false
    t.string "status", default: "configured", null: false
    t.datetime "updated_at", null: false
    t.index ["coverage_geometry"], name: "index_cadastre_source_archives_on_coverage_geometry", using: :gist
    t.index ["coverage_profile_key", "enabled"], name: "idx_on_coverage_profile_key_enabled_9e640abb04"
    t.index ["latest_successful_import_id"], name: "index_cadastre_source_archives_on_latest_successful_import_id"
    t.index ["source_archive_key", "coverage_profile_key"], name: "idx_cadastre_archives_key_profile", unique: true
  end

  create_table "dataset_imports", force: :cascade do |t|
    t.string "checksum"
    t.datetime "completed_at"
    t.string "coverage_profile_key"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "importer_version", default: 1, null: false
    t.jsonb "outcome_counts", default: {}, null: false
    t.integer "records_created", default: 0, null: false
    t.integer "records_removed", default: 0, null: false
    t.integer "records_seen", default: 0, null: false
    t.integer "records_updated", default: 0, null: false
    t.datetime "relevant_at"
    t.string "scope_digest", default: "unscoped", null: false
    t.bigint "spatial_dataset_id", null: false
    t.datetime "started_at"
    t.string "status", default: "running", null: false
    t.datetime "updated_at", null: false
    t.index ["spatial_dataset_id", "checksum", "importer_version", "scope_digest"], name: "idx_dataset_imports_source_version_scope"
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
    t.datetime "immediate_performance_consented_at"
    t.string "legal_document_version"
    t.datetime "paid_at"
    t.string "payment_provider", null: false
    t.string "product_code", null: false
    t.bigint "property_analysis_id", null: false
    t.string "provider_reference"
    t.uuid "public_token", default: -> { "gen_random_uuid()" }, null: false
    t.string "status", default: "pending", null: false
    t.datetime "terms_accepted_at"
    t.datetime "updated_at", null: false
    t.datetime "withdrawal_loss_acknowledged_at"
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
    t.geography "analysis_point", limit: {srid: 4326, type: "st_point", geographic: true}
    t.string "analysis_scope_status", default: "unknown", null: false
    t.geometry "building_geometry", limit: {srid: 4326, type: "geometry"}
    t.string "building_identifier"
    t.geography "centroid", limit: {srid: 4326, type: "st_point", geographic: true}
    t.datetime "completed_at"
    t.string "coverage_profile_key"
    t.string "coverage_status", default: "limited", null: false
    t.datetime "created_at", null: false
    t.datetime "failed_at"
    t.text "failure_message"
    t.jsonb "geometry_bases", default: {}, null: false
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
    t.geometry "subject_geometry", limit: {srid: 4326, type: "geometry"}
    t.string "submitted_identifier", null: false
    t.jsonb "summary", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_point"], name: "index_property_analyses_on_analysis_point", using: :gist
    t.index ["building_geometry"], name: "index_property_analyses_on_building_geometry", using: :gist
    t.index ["centroid"], name: "index_property_analyses_on_centroid", using: :gist
    t.index ["parcel_geometry"], name: "index_property_analyses_on_parcel_geometry", using: :gist
    t.index ["public_token"], name: "index_property_analyses_on_public_token", unique: true
    t.index ["subject_geometry"], name: "index_property_analyses_on_subject_geometry", using: :gist
    t.index ["submitted_identifier", "completed_at"], name: "idx_on_submitted_identifier_completed_at_29246503d7"
  end

  create_table "property_graph_entities", force: :cascade do |t|
    t.string "canonical_key", null: false
    t.datetime "created_at", null: false
    t.string "display_name", null: false
    t.string "entity_type", null: false
    t.datetime "first_observed_at", null: false
    t.jsonb "identifiers", default: {}, null: false
    t.datetime "last_observed_at", null: false
    t.datetime "updated_at", null: false
    t.index ["canonical_key"], name: "index_property_graph_entities_on_canonical_key", unique: true
    t.index ["entity_type", "display_name"], name: "index_property_graph_entities_on_entity_type_and_display_name"
    t.index ["identifiers"], name: "index_property_graph_entities_on_identifiers", using: :gin
  end

  create_table "property_graph_entity_observations", force: :cascade do |t|
    t.string "claim_origin", default: "public_source", null: false
    t.text "coverage_limitation"
    t.datetime "created_at", null: false
    t.jsonb "evidence", default: {}, null: false
    t.jsonb "facts", default: {}, null: false
    t.string "fingerprint", null: false
    t.datetime "observed_at", null: false
    t.bigint "property_analysis_id", null: false
    t.bigint "property_graph_entity_id", null: false
    t.datetime "source_date"
    t.string "source_key", null: false
    t.string "source_record_reference", null: false
    t.bigint "source_run_id"
    t.text "source_url", null: false
    t.datetime "updated_at", null: false
    t.index ["fingerprint"], name: "idx_property_graph_observations_fingerprint", unique: true
    t.index ["property_analysis_id", "source_key"], name: "idx_property_graph_observations_analysis_source"
    t.index ["property_analysis_id"], name: "idx_on_property_analysis_id_fc85463579"
    t.index ["property_graph_entity_id"], name: "idx_on_property_graph_entity_id_449a2098e3"
    t.index ["source_run_id"], name: "index_property_graph_entity_observations_on_source_run_id"
  end

  create_table "property_graph_relationships", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "claim_origin", default: "public_source", null: false
    t.text "coverage_limitation"
    t.datetime "created_at", null: false
    t.jsonb "evidence", default: {}, null: false
    t.string "fingerprint", null: false
    t.datetime "first_observed_at", null: false
    t.datetime "last_observed_at", null: false
    t.bigint "object_entity_id", null: false
    t.jsonb "object_scope", default: {}, null: false
    t.bigint "property_analysis_id", null: false
    t.string "refresh_scope", null: false
    t.string "relationship_type", null: false
    t.datetime "source_date"
    t.string "source_key", null: false
    t.string "source_record_reference", null: false
    t.bigint "source_run_id"
    t.text "source_url", null: false
    t.string "status", null: false
    t.bigint "subject_entity_id", null: false
    t.jsonb "subject_scope", default: {}, null: false
    t.datetime "superseded_at"
    t.datetime "updated_at", null: false
    t.date "valid_from"
    t.date "valid_until"
    t.index ["fingerprint"], name: "index_property_graph_relationships_on_fingerprint", unique: true
    t.index ["object_entity_id"], name: "index_property_graph_relationships_on_object_entity_id"
    t.index ["property_analysis_id", "active"], name: "idx_property_graph_relationships_analysis_active"
    t.index ["property_analysis_id", "source_key", "refresh_scope"], name: "idx_property_graph_relationships_refresh"
    t.index ["property_analysis_id"], name: "index_property_graph_relationships_on_property_analysis_id"
    t.index ["source_run_id"], name: "index_property_graph_relationships_on_source_run_id"
    t.index ["subject_entity_id"], name: "index_property_graph_relationships_on_subject_entity_id"
  end

  create_table "shared_spatial_calculations", force: :cascade do |t|
    t.datetime "calculated_at", null: false
    t.string "calculation_kind", null: false
    t.string "coverage_profile_key", null: false
    t.datetime "created_at", null: false
    t.jsonb "dataset_revisions", default: {}, null: false
    t.string "fingerprint", null: false
    t.string "geometry_basis", null: false
    t.jsonb "result", default: {}, null: false
    t.string "subject_key", null: false
    t.datetime "updated_at", null: false
    t.index ["fingerprint"], name: "index_shared_spatial_calculations_on_fingerprint", unique: true
    t.index ["subject_key", "calculation_kind"], name: "idx_shared_calculations_subject_kind"
  end

  create_table "source_runs", force: :cascade do |t|
    t.bigint "analysis_revision_id"
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
    t.index ["analysis_revision_id"], name: "index_source_runs_on_analysis_revision_id"
    t.index ["property_analysis_id", "source_key"], name: "index_source_runs_on_property_analysis_id_and_source_key"
    t.index ["property_analysis_id"], name: "index_source_runs_on_property_analysis_id"
  end

  create_table "source_snapshots", force: :cascade do |t|
    t.text "attribution"
    t.string "checksum"
    t.string "coverage_profile_key", null: false
    t.string "coverage_status", default: "partial", null: false
    t.datetime "created_at", null: false
    t.datetime "fetched_at"
    t.jsonb "metadata", default: {}, null: false
    t.text "permission_reference"
    t.string "permission_status", default: "review_required", null: false
    t.string "provider", null: false
    t.integer "record_count", default: 0, null: false
    t.datetime "relevant_at"
    t.string "revision"
    t.string "source_key", null: false
    t.string "source_url", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["source_key", "coverage_profile_key", "created_at"], name: "idx_source_snapshots_key_profile_created"
  end

  create_table "spatial_datasets", force: :cascade do |t|
    t.text "attribution"
    t.geometry "coverage_geometry", limit: {srid: 4326, type: "geometry"}
    t.string "coverage_profile_key"
    t.string "coverage_status", default: "partial", null: false
    t.datetime "created_at", null: false
    t.string "external_dataset_id"
    t.integer "importer_version", default: 1, null: false
    t.string "key", null: false
    t.datetime "last_imported_at"
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.text "permission_reference"
    t.string "permission_status", default: "review_required", null: false
    t.string "provider", null: false
    t.datetime "relevant_at"
    t.string "source_checksum"
    t.string "source_revision"
    t.string "source_url", null: false
    t.datetime "updated_at", null: false
    t.index ["coverage_geometry"], name: "index_spatial_datasets_on_coverage_geometry", using: :gist
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
  add_foreign_key "analysis_revisions", "property_analyses"
  add_foreign_key "budget_scenarios", "buyer_journeys"
  add_foreign_key "budget_scenarios", "property_analyses"
  add_foreign_key "buyer_journeys", "property_analyses"
  add_foreign_key "cadastre_source_archives", "cadastre_imports", column: "latest_successful_import_id"
  add_foreign_key "dataset_imports", "spatial_datasets"
  add_foreign_key "journey_item_progresses", "buyer_journeys"
  add_foreign_key "orders", "property_analyses"
  add_foreign_key "product_events", "orders"
  add_foreign_key "product_events", "property_analyses"
  add_foreign_key "property_graph_entity_observations", "property_analyses"
  add_foreign_key "property_graph_entity_observations", "property_graph_entities"
  add_foreign_key "property_graph_entity_observations", "source_runs"
  add_foreign_key "property_graph_relationships", "property_analyses"
  add_foreign_key "property_graph_relationships", "property_graph_entities", column: "object_entity_id"
  add_foreign_key "property_graph_relationships", "property_graph_entities", column: "subject_entity_id"
  add_foreign_key "property_graph_relationships", "source_runs"
  add_foreign_key "source_runs", "analysis_revisions"
  add_foreign_key "source_runs", "property_analyses"
  add_foreign_key "spatial_features", "spatial_datasets"
end
