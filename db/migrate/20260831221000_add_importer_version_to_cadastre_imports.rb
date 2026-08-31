class AddImporterVersionToCadastreImports < ActiveRecord::Migration[8.1]
  def change
    add_column :cadastre_imports, :importer_version, :integer, null: false, default: 1
  end
end
