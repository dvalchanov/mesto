class ImportOpenStreetMapDatasetJob < ApplicationJob
  queue_as :ingestion

  def perform(coverage_profile_key: DataCoverage.profile.key)
    profile = DataCoverage::Profile.find(coverage_profile_key)
    DataSources::OpenStreetMap::DatasetSynchronizer.new(coverage_profile: profile).sync
  end
end
