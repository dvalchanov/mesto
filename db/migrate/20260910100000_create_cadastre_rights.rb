class CreateCadastreRights < ActiveRecord::Migration[8.1]
  def change
    create_table :cadastre_rights do |t|
      t.string :cadastral_identifier, null: false
      t.string :identifier_level, null: false
      t.string :property_type
      t.string :right_code
      t.string :right_type, null: false
      t.text :right_description
      t.string :holder_type_code
      t.string :holder_type, null: false
      t.string :holder_name, null: false
      t.string :holder_identifier
      t.string :holder_entity_type, null: false
      t.text :holder_note
      t.string :document_code
      t.string :document_type
      t.text :document_description
      t.text :document_note
      t.string :source_archive_key, null: false
      t.text :source_url, null: false
      t.datetime :source_relevant_at
      t.string :record_fingerprint, null: false
      t.timestamps

      t.index :cadastral_identifier
      t.index :holder_identifier
      t.index [ :holder_entity_type, :holder_name ]
      t.index :record_fingerprint, unique: true
      t.index :source_archive_key
    end
  end
end
