class AddPreparedDataArchitecture < ActiveRecord::Migration[8.1]
  def change
    create_table :cadastre_source_archives do |t|
      t.string :source_archive_key, null: false
      t.string :district, null: false
      t.string :object_kind, null: false
      t.string :source_url, null: false
      t.string :coverage_profile_key, null: false
      t.geometry :coverage_geometry, geographic: false, srid: 4326
      t.boolean :enabled, null: false, default: false
      t.string :status, null: false, default: "configured"
      t.datetime :discovered_at
      t.datetime :last_checked_at
      t.bigint :latest_successful_import_id
      t.string :permission_status, null: false, default: "review_required"
      t.text :attribution
      t.text :permission_reference
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :cadastre_source_archives, [ :source_archive_key, :coverage_profile_key ],
      unique: true,
      name: "idx_cadastre_archives_key_profile"
    add_index :cadastre_source_archives, [ :coverage_profile_key, :enabled ]
    add_index :cadastre_source_archives, :coverage_geometry, using: :gist

    remove_index :cadastre_imports, name: "index_cadastre_imports_on_source_archive_key_and_checksum"
    add_column :cadastre_imports, :coverage_profile_key, :string, null: false, default: "legacy"
    add_column :cadastre_imports, :scope_digest, :string, null: false, default: "unscoped"
    add_column :cadastre_imports, :source_checksum, :string
    add_column :cadastre_imports, :source_checked_at, :datetime
    add_column :cadastre_imports, :source_last_modified_at, :datetime
    add_column :cadastre_imports, :source_etag, :string
    add_column :cadastre_imports, :outcome_counts, :jsonb, null: false, default: {}
    add_column :cadastre_imports, :validation_errors, :jsonb, null: false, default: {}
    add_index :cadastre_imports,
      [ :source_archive_key, :source_checksum, :importer_version, :scope_digest ],
      unique: true,
      name: "idx_cadastre_imports_source_version_scope",
      where: "source_checksum IS NOT NULL"

    add_column :spatial_datasets, :coverage_profile_key, :string
    add_column :spatial_datasets, :coverage_geometry, :geometry, geographic: false, srid: 4326
    add_column :spatial_datasets, :source_revision, :string
    add_column :spatial_datasets, :source_checksum, :string
    add_column :spatial_datasets, :importer_version, :integer, null: false, default: 1
    add_column :spatial_datasets, :coverage_status, :string, null: false, default: "partial"
    add_column :spatial_datasets, :permission_status, :string, null: false, default: "review_required"
    add_column :spatial_datasets, :attribution, :text
    add_column :spatial_datasets, :permission_reference, :text
    add_index :spatial_datasets, :coverage_geometry, using: :gist

    add_column :dataset_imports, :importer_version, :integer, null: false, default: 1
    add_column :dataset_imports, :coverage_profile_key, :string
    add_column :dataset_imports, :scope_digest, :string, null: false, default: "unscoped"
    add_column :dataset_imports, :outcome_counts, :jsonb, null: false, default: {}
    add_column :dataset_imports, :relevant_at, :datetime
    add_index :dataset_imports,
      [ :spatial_dataset_id, :checksum, :importer_version, :scope_digest ],
      name: "idx_dataset_imports_source_version_scope"

    create_table :source_snapshots do |t|
      t.string :source_key, null: false
      t.string :provider, null: false
      t.string :source_url, null: false
      t.string :coverage_profile_key, null: false
      t.string :status, null: false
      t.string :coverage_status, null: false, default: "partial"
      t.string :revision
      t.string :checksum
      t.integer :record_count, null: false, default: 0
      t.datetime :fetched_at
      t.datetime :relevant_at
      t.string :permission_status, null: false, default: "review_required"
      t.text :attribution
      t.text :permission_reference
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :source_snapshots, [ :source_key, :coverage_profile_key, :created_at ],
      name: "idx_source_snapshots_key_profile_created"

    create_table :analysis_revisions do |t|
      t.references :property_analysis, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :status, null: false, default: "running"
      t.string :coverage_profile_key, null: false
      t.integer :calculation_version, null: false, default: 1
      t.jsonb :dataset_revisions, null: false, default: {}
      t.jsonb :geometry_bases, null: false, default: {}
      t.jsonb :report_snapshot, null: false, default: {}
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
      t.timestamps
    end
    add_index :analysis_revisions, [ :property_analysis_id, :number ], unique: true

    add_reference :source_runs, :analysis_revision, foreign_key: true

    add_column :property_analyses, :coverage_profile_key, :string
    add_column :property_analyses, :analysis_scope_status, :string, null: false, default: "unknown"
    add_column :property_analyses, :analysis_point, :st_point, geographic: true, srid: 4326
    add_column :property_analyses, :subject_geometry, :geometry, geographic: false, srid: 4326
    add_column :property_analyses, :building_geometry, :geometry, geographic: false, srid: 4326
    add_column :property_analyses, :geometry_bases, :jsonb, null: false, default: {}
    add_index :property_analyses, :analysis_point, using: :gist
    add_index :property_analyses, :subject_geometry, using: :gist
    add_index :property_analyses, :building_geometry, using: :gist

    create_table :shared_spatial_calculations do |t|
      t.string :subject_key, null: false
      t.string :calculation_kind, null: false
      t.string :cache_key, null: false
      t.string :geometry_basis, null: false
      t.string :coverage_profile_key, null: false
      t.jsonb :dataset_revisions, null: false, default: {}
      t.jsonb :result, null: false, default: {}
      t.datetime :calculated_at, null: false
      t.timestamps
    end
    add_index :shared_spatial_calculations, :cache_key, unique: true
    add_index :shared_spatial_calculations, [ :subject_key, :calculation_kind ],
      name: "idx_shared_calculations_subject_kind"
  end
end
