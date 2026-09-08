class RefreshPreparedDataJob < ApplicationJob
  queue_as :ingestion

  REFRESH_INTERVAL = 1.day

  def perform(coverage_profile_key: DataCoverage.profile.key)
    profile = DataCoverage::Profile.find(coverage_profile_key)
    return unless profile.import_behavior == "scheduled"

    catalog = DataSources::CadastreOpenData::SourceCatalog.new(profile:).ensure_profile_entries!
    catalog.select { |entry| entry.enabled? && refresh_due?(entry.last_checked_at) }
      .each { |entry| ImportCadastreArchiveJob.perform_later(entry.id) }

    ImportSpatialDatasetJob.perform_later(nil, coverage_profile_key: profile.key)
    ImportArcGisDatasetJob.perform_later(nil, coverage_profile_key: profile.key)
    ImportOpenStreetMapDatasetJob.perform_later(coverage_profile_key: profile.key)
  end

  private

  def refresh_due?(timestamp)
    timestamp.nil? || timestamp < REFRESH_INTERVAL.ago
  end
end
