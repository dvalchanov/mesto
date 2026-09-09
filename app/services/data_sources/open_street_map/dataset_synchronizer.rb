module DataSources
  module OpenStreetMap
    class DatasetSynchronizer
      def initialize(
        coverage_profile: DataCoverage.profile,
        client: NearbyAmenitiesClient.new,
        archive_store: DataSources::SourceArchives.store
      )
        @coverage_profile = coverage_profile
        @client = client
        @archive_store = archive_store
      end

      def sync
        config = DataSources.config.fetch("openstreetmap")
        ensure_ingestion_allowed!(config)
        result = @client.fetch_coverage(bounds: @coverage_profile.bounding_box)
        return result unless result.success?

        import_result(config, result)
      end

      def replay
        config = DataSources.config.fetch("openstreetmap")
        ensure_ingestion_allowed!(config)
        result = DataSources::SourceArchives.replay_json(
          store: @archive_store,
          provider: "openstreetmap",
          source_key: config.fetch("dataset_key"),
          coverage_profile: @coverage_profile
        )
        import_result(config, result)
      end

      private

      def import_result(config, result)
        DataSources::SourceArchives.import_json(
          store: @archive_store,
          result:,
          provider: "openstreetmap",
          source_key: config.fetch("dataset_key"),
          coverage_profile: @coverage_profile
        ) do
          Sofiaplan::GeojsonImporter.new(
            dataset_config: {
              "key" => config.fetch("dataset_key"),
              "category" => "schools",
              "name" => "OpenStreetMap schools and kindergartens",
              "provider" => "OpenStreetMap",
              "coverage_status" => config.fetch("coverage_status", "partial"),
              "permission_status" => config.fetch("permission_status", "review_required"),
              "attribution" => config["attribution"],
              "permission_reference" => config["permission_reference"]
            },
            payload: result.data,
            source_url: result.source_url,
            coverage_profile: @coverage_profile,
            relevant_at: result.relevant_at
          ).call
        end
      end

      def ensure_ingestion_allowed!(config)
        DataSources::PermissionGate.ensure_bulk_ingestion_allowed!(
          config.fetch("permission_status", "review_required"),
          source: "OpenStreetMap amenities"
        )
      end
    end
  end
end
