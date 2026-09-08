class RenameSharedCalculationCacheKey < ActiveRecord::Migration[8.1]
  def change
    rename_column :shared_spatial_calculations, :cache_key, :fingerprint
  end
end
