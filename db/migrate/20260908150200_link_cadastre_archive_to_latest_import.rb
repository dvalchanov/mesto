class LinkCadastreArchiveToLatestImport < ActiveRecord::Migration[8.1]
  def change
    add_index :cadastre_source_archives, :latest_successful_import_id
    add_foreign_key :cadastre_source_archives, :cadastre_imports, column: :latest_successful_import_id
  end
end
