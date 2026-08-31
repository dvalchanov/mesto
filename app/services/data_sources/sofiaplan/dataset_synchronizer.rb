module DataSources
  module Sofiaplan
    class DatasetSynchronizer
      def initialize(dataset_client: DatasetClient.new)
        @dataset_client = dataset_client
      end

      def sync(key = nil)
        configurations = DataSources.config.dig("sofiaplan", "datasets")
        configurations = configurations.slice(key.to_s) if key
        configurations.map do |dataset_key, dataset_config|
          result = @dataset_client.fetch(dataset_config.fetch("id"))
          if result.success?
            imported = GeojsonImporter.new(
              dataset_config: dataset_config.merge("category" => dataset_key),
              payload: result.data,
              source_url: result.source_url
            ).call
            [ dataset_key, imported ]
          else
            [ dataset_key, result ]
          end
        end.to_h
      end
    end
  end
end
