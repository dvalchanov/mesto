class CreatePropertyIntelligenceTables < ActiveRecord::Migration[8.1]
  def change
    create_table :property_analyses do |t|
      t.uuid :public_token, null: false, default: -> { "gen_random_uuid()" }
      t.string :submitted_identifier, null: false
      t.string :settlement_code, null: false
      t.string :parcel_identifier, null: false
      t.string :building_identifier
      t.string :individual_object_identifier
      t.string :identifier_level, null: false
      t.string :status, null: false, default: "queued"
      t.string :coverage_status, null: false, default: "limited"
      t.st_point :centroid, geographic: true, srid: 4326
      t.multi_polygon :parcel_geometry, geographic: false, srid: 4326
      t.string :location_precision, null: false, default: "unavailable"
      t.jsonb :summary, null: false, default: {}
      t.jsonb :metrics, null: false, default: {}
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :failed_at
      t.text :failure_message
      t.timestamps
    end
    add_index :property_analyses, :public_token, unique: true
    add_index :property_analyses, [ :submitted_identifier, :completed_at ]
    add_index :property_analyses, :centroid, using: :gist
    add_index :property_analyses, :parcel_geometry, using: :gist

    create_table :source_runs do |t|
      t.references :property_analysis, null: false, foreign_key: true
      t.string :source_key, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :request_metadata, null: false, default: {}
      t.jsonb :parsed_payload, null: false, default: {}
      t.string :source_url
      t.datetime :fetched_at
      t.datetime :relevant_at
      t.string :checksum
      t.string :error_class
      t.text :error_message
      t.text :raw_response
      t.timestamps
    end
    add_index :source_runs, [ :property_analysis_id, :source_key ]

    create_table :administrative_acts do |t|
      t.string :registry_kind, null: false
      t.string :external_key, null: false
      t.string :act_number
      t.string :title
      t.string :status
      t.date :issued_on
      t.date :effective_on
      t.string :issuer
      t.string :district
      t.string :locality
      t.string :upi
      t.string :address
      t.text :object_description
      t.string :construction_category
      t.decimal :built_up_area, precision: 14, scale: 2
      t.decimal :gross_floor_area, precision: 14, scale: 2
      t.geometry :geometry, geographic: false, srid: 4326
      t.string :source_url, null: false
      t.string :document_url
      t.jsonb :properties, null: false, default: {}
      t.timestamps
    end
    add_index :administrative_acts, [ :registry_kind, :external_key ], unique: true
    add_index :administrative_acts, :geometry, using: :gist

    create_table :administrative_act_references do |t|
      t.references :administrative_act, null: false, foreign_key: true
      t.string :cadastral_identifier, null: false
      t.string :reference_level, null: false
      t.timestamps
    end
    add_index :administrative_act_references,
      [ :administrative_act_id, :cadastral_identifier ],
      unique: true,
      name: "idx_act_refs_on_act_and_identifier"
    add_index :administrative_act_references, :cadastral_identifier

    create_table :spatial_datasets do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :provider, null: false
      t.string :external_dataset_id
      t.string :source_url, null: false
      t.datetime :relevant_at
      t.datetime :last_imported_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :spatial_datasets, :key, unique: true

    create_table :spatial_features do |t|
      t.references :spatial_dataset, null: false, foreign_key: true
      t.string :external_key, null: false
      t.string :category, null: false
      t.string :name
      t.string :address
      t.geometry :geometry, geographic: false, srid: 4326, null: false
      t.jsonb :properties, null: false, default: {}
      t.timestamps
    end
    add_index :spatial_features, [ :spatial_dataset_id, :external_key ], unique: true
    add_index :spatial_features, :category
    add_index :spatial_features, :geometry, using: :gist

    create_table :dataset_imports do |t|
      t.references :spatial_dataset, null: false, foreign_key: true
      t.string :status, null: false, default: "running"
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :records_seen, null: false, default: 0
      t.integer :records_created, null: false, default: 0
      t.integer :records_updated, null: false, default: 0
      t.integer :records_removed, null: false, default: 0
      t.string :checksum
      t.text :error_message
      t.timestamps
    end

    create_table :orders do |t|
      t.uuid :public_token, null: false, default: -> { "gen_random_uuid()" }
      t.references :property_analysis, null: false, foreign_key: true
      t.string :product_code, null: false
      t.string :email, null: false
      t.integer :amount_cents, null: false
      t.string :currency, null: false
      t.string :status, null: false, default: "pending"
      t.string :payment_provider, null: false
      t.string :provider_reference
      t.datetime :paid_at
      t.datetime :failed_at
      t.datetime :cancelled_at
      t.timestamps
    end
    add_index :orders, :public_token, unique: true
    add_index :orders, [ :property_analysis_id, :status ]
    add_index :orders, :provider_reference, unique: true, where: "provider_reference IS NOT NULL"

    create_table :product_events do |t|
      t.references :property_analysis, foreign_key: true
      t.references :order, foreign_key: true
      t.string :name, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :product_events, [ :name, :occurred_at ]
  end
end
