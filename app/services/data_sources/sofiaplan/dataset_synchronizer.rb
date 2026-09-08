module DataSources
  module Sofiaplan
    class DatasetSynchronizer
      def initialize(dataset_client: DatasetClient.new, coverage_profile: DataCoverage.profile)
        @dataset_client = dataset_client
        @coverage_profile = coverage_profile
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
        DataSources::PermissionGate.ensure_bulk_ingestion_allowed!(
          source_config.fetch("permission_status", "review_required"),
          source: "SofiaPlan #{dataset_key}"
        )
        result = @dataset_client.fetch(dataset_config.fetch("id"))
        return result unless result.success?

        GeojsonImporter.new(
          dataset_config: dataset_config.merge(
            "category" => dataset_key,
            "key" => dataset_key,
            "coverage_status" => "complete",
            "permission_status" => source_config.fetch("permission_status", "review_required"),
            "attribution" => source_config["attribution"],
            "permission_reference" => source_config["permission_reference"]
          ),
          payload: result.data,
          source_url: result.source_url,
          coverage_profile: @coverage_profile,
          relevant_at: result.relevant_at
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


      def source_config
        @source_config ||= DataSources.config.fetch("sofiaplan")
      end
    end
  end
end
