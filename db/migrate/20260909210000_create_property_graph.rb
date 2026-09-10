class CreatePropertyGraph < ActiveRecord::Migration[8.1]
  def change
    create_table :property_graph_entities do |t|
      t.string :entity_type, null: false
      t.string :canonical_key, null: false
      t.string :display_name, null: false
      t.jsonb :identifiers, null: false, default: {}
      t.datetime :first_observed_at, null: false
      t.datetime :last_observed_at, null: false
      t.timestamps

      t.index :canonical_key, unique: true
      t.index [ :entity_type, :display_name ]
      t.index :identifiers, using: :gin
    end

    create_table :property_graph_entity_observations do |t|
      t.references :property_graph_entity, null: false, foreign_key: true
      t.references :property_analysis, null: false, foreign_key: true
      t.references :source_run, null: true, foreign_key: true
      t.string :source_key, null: false
      t.text :source_url, null: false
      t.string :source_record_reference, null: false
      t.datetime :source_date
      t.datetime :observed_at, null: false
      t.string :claim_origin, null: false, default: "public_source"
      t.jsonb :attributes, null: false, default: {}
      t.jsonb :evidence, null: false, default: {}
      t.text :coverage_limitation
      t.string :fingerprint, null: false
      t.timestamps

      t.index :fingerprint, unique: true, name: "idx_property_graph_observations_fingerprint"
      t.index [ :property_analysis_id, :source_key ], name: "idx_property_graph_observations_analysis_source"
    end

    create_table :property_graph_relationships do |t|
      t.references :property_analysis, null: false, foreign_key: true
      t.references :source_run, null: true, foreign_key: true
      t.bigint :subject_entity_id, null: false
      t.bigint :object_entity_id, null: false
      t.string :relationship_type, null: false
      t.string :status, null: false
      t.string :claim_origin, null: false, default: "public_source"
      t.string :source_key, null: false
      t.text :source_url, null: false
      t.string :source_record_reference, null: false
      t.datetime :source_date
      t.datetime :first_observed_at, null: false
      t.datetime :last_observed_at, null: false
      t.date :valid_from
      t.date :valid_until
      t.boolean :active, null: false, default: true
      t.datetime :superseded_at
      t.jsonb :subject_scope, null: false, default: {}
      t.jsonb :object_scope, null: false, default: {}
      t.jsonb :evidence, null: false, default: {}
      t.text :coverage_limitation
      t.string :refresh_scope, null: false
      t.string :fingerprint, null: false
      t.timestamps

      t.index :fingerprint, unique: true
      t.index [ :property_analysis_id, :active ], name: "idx_property_graph_relationships_analysis_active"
      t.index [ :property_analysis_id, :source_key, :refresh_scope ], name: "idx_property_graph_relationships_refresh"
      t.index :subject_entity_id
      t.index :object_entity_id
    end

    add_foreign_key :property_graph_relationships, :property_graph_entities, column: :subject_entity_id
    add_foreign_key :property_graph_relationships, :property_graph_entities, column: :object_entity_id
  end
end
