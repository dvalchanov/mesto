class AddCadastralAddressSearchIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_cadastral_properties_address_search
      ON cadastral_properties USING gin (lower(address) gin_trgm_ops)
      WHERE identifier_level = 'individual_object' AND address IS NOT NULL
    SQL
  end

  def down
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_cadastral_properties_address_search"
  end
end
