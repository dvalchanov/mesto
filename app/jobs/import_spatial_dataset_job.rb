class ImportSpatialDatasetJob < ApplicationJob
  queue_as :ingestion

  def perform(dataset_key = nil, coverage_profile_key: DataCoverage.profile.key)
    profile = DataCoverage::Profile.find(coverage_profile_key)
    DataSources::Sofiaplan::DatasetSynchronizer.new(coverage_profile: profile).sync(dataset_key)
  end
end
