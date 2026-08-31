class ImportSpatialDatasetJob < ApplicationJob
  queue_as :imports

  def perform(dataset_key = nil)
    DataSources::Sofiaplan::DatasetSynchronizer.new.sync(dataset_key)
  end
end
