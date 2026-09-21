class LegalController < ApplicationController
  def notice; end
  def terms; end
  def privacy; end
  def cookie_notice
    render :cookies
  end

  def data_sources
    @spatial_datasets = SpatialDataset.order(:key).index_by(&:key)
    @latest_nag_snapshots = SourceSnapshot
      .where(source_key: DataSources.config.dig("nag", "registers").keys.map { |key| "nag_#{key}" })
      .order(created_at: :desc)
      .group_by(&:source_key)
      .transform_values(&:first)
    @cadastre_archives = CadastreSourceArchive.order(:district, :object_kind).to_a
    @cadastre_imports = @cadastre_archives.filter_map(&:latest_successful_import)
  end
end
