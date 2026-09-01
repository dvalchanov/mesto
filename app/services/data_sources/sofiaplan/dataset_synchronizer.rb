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
          [ dataset_key, sync_dataset(dataset_key, dataset_config) ]
        end.to_h
      end

      private

      def sync_dataset(dataset_key, dataset_config)
        result = @dataset_client.fetch(dataset_config.fetch("id"))
        return result unless result.success?

        GeojsonImporter.new(
          dataset_config: dataset_config.merge("category" => dataset_key),
          payload: result.data,
          source_url: result.source_url
        ).call
      rescue StandardError => error
        DataSources::Result.failure(
          source_url: result&.source_url || dataset_url(dataset_config),
          error:
        )
      end

      def dataset_url(dataset_config)
        "#{DataSources.config.dig('sofiaplan', 'base_url')}/datasets/#{dataset_config.fetch('id')}"
      end
    end
  end
end
