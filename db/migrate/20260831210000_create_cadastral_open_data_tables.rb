class CreateCadastralOpenDataTables < ActiveRecord::Migration[8.1]
  def change
    create_table :cadastral_properties do |t|
      t.string :cadastral_identifier, null: false
      t.string :identifier_level, null: false
      t.decimal :area_sqm, precision: 14, scale: 2
      t.string :object_number
      t.string :floor
      t.integer :levels_count
      t.string :entrance
      t.string :purpose
      t.string :address
      t.string :district
      t.string :locality
      t.text :additional_parts
      t.text :validation_document
      t.string :source_archive_key, null: false
      t.string :source_url, null: false
      t.datetime :source_relevant_at
      t.jsonb :properties, null: false, default: {}
      t.timestamps
    end
    add_index :cadastral_properties, :cadastral_identifier, unique: true
    add_index :cadastral_properties, :source_archive_key

    create_table :cadastre_imports do |t|
      t.string :source_archive_key, null: false
      t.string :source_url, null: false
      t.string :status, null: false, default: "running"
      t.datetime :relevant_at
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :records_seen, null: false, default: 0
      t.integer :records_imported, null: false, default: 0
      t.string :checksum
      t.text :error_message
      t.timestamps
    end
    add_index :cadastre_imports, [ :source_archive_key, :checksum ], unique: true
    add_index :cadastre_imports, [ :source_archive_key, :status ]
  end
end
