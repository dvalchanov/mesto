class RenamePropertyGraphObservationAttributes < ActiveRecord::Migration[8.1]
  def change
    rename_column :property_graph_entity_observations, :attributes, :facts
  end
end
