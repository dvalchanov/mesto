module DataSources
  module ArcGis
    class DatasetSynchronizer
      def initialize(
        coverage_profile: DataCoverage.profile,
        archive_store: DataSources::SourceArchives.store
      )
        @coverage_profile = coverage_profile
        @archive_store = archive_store
      end

      def sync(key = nil)
        configurations = DataSources.config.fetch("arcgis")
        configurations = configurations.slice(key.to_s) if key
        configurations.to_h do |dataset_key, config|
          [ dataset_key, sync_dataset(dataset_key, config) ]
        end
      end

      def replay(key = nil)
        configurations = DataSources.config.fetch("arcgis")
        configurations = configurations.slice(key.to_s) if key
        configurations.to_h do |dataset_key, config|
          [ dataset_key, replay_dataset(dataset_key, config) ]
        end
      end

      private

      def sync_dataset(dataset_key, config)
        ensure_ingestion_allowed!(dataset_key, config)
        result = FeatureLayerClient.new(layer_url: config.fetch("url"))
          .query(geometry: @coverage_profile.supporting_geometry)
        return result unless result.success?

        import_result(dataset_key, config, result)
      rescue StandardError => error
        DataSources::Result.failure(source_url: config.fetch("url"), error:)
      end

      def replay_dataset(dataset_key, config)
        ensure_ingestion_allowed!(dataset_key, config)
        result = DataSources::SourceArchives.replay_json(
          store: @archive_store,
          provider: "sofiaplan-arcgis",
          source_key: dataset_key,
          coverage_profile: @coverage_profile
        )
        import_result(dataset_key, config, result)
      rescue StandardError => error
        DataSources::Result.failure(source_url: config.fetch("url"), error:)
      end

      def import_result(dataset_key, config, result)
        DataSources::SourceArchives.import_json(
          store: @archive_store,
          result:,
          provider: "sofiaplan-arcgis",
          source_key: dataset_key,
          coverage_profile: @coverage_profile
        ) do
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
        end
      end

      def ensure_ingestion_allowed!(dataset_key, config)
        DataSources::PermissionGate.ensure_bulk_ingestion_allowed!(
          config.fetch("permission_status", "review_required"),
          source: "arcgis_#{dataset_key}"
        )
      end
    end
  end
end
