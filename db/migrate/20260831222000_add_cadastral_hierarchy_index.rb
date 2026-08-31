class AddCadastralHierarchyIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :cadastral_properties, [ :identifier_level, :cadastral_identifier ],
      name: "idx_cadastral_properties_hierarchy"
  end
end
