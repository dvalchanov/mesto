class AddCadastralBuildingAddressSearchIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_cadastral_buildings_address_search
      ON cadastral_properties USING gin (lower(address) gin_trgm_ops)
      WHERE identifier_level = 'building' AND address IS NOT NULL
    SQL
  end

  def down
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_cadastral_buildings_address_search"
  end
end
