module DataSources
  module ArcGis
    class DatasetSynchronizer
      def initialize(coverage_profile: DataCoverage.profile)
        @coverage_profile = coverage_profile
      end

      def sync(key = nil)
        configurations = DataSources.config.fetch("arcgis")
        configurations = configurations.slice(key.to_s) if key
        configurations.to_h do |dataset_key, config|
          [ dataset_key, sync_dataset(dataset_key, config) ]
        end
      end

      private

      def sync_dataset(dataset_key, config)
        DataSources::PermissionGate.ensure_bulk_ingestion_allowed!(
          config.fetch("permission_status", "review_required"),
          source: "arcgis_#{dataset_key}"
        )
        result = FeatureLayerClient.new(layer_url: config.fetch("url"))
          .query(geometry: @coverage_profile.supporting_geometry)
        return result unless result.success?

        Sofiaplan::GeojsonImporter.new(
          dataset_config: config.merge(
            "key" => "arcgis_#{dataset_key}",
            "category" => "planning_#{dataset_key}",
            "provider" => "Софияплан ArcGIS",
            "coverage_status" => "complete"
          ),
          payload: result.data,
          source_url: result.source_url,
          coverage_profile: @coverage_profile,
          relevant_at: result.relevant_at
        ).call
      rescue StandardError => error
        DataSources::Result.failure(source_url: config.fetch("url"), error:)
      end
    end
  end
end
