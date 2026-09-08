module DataSources
  module OpenStreetMap
    class DatasetSynchronizer
      def initialize(coverage_profile: DataCoverage.profile, client: NearbyAmenitiesClient.new)
        @coverage_profile = coverage_profile
        @client = client
      end

      def sync
        config = DataSources.config.fetch("openstreetmap")
        DataSources::PermissionGate.ensure_bulk_ingestion_allowed!(
          config.fetch("permission_status", "review_required"),
          source: "OpenStreetMap amenities"
        )
        result = @client.fetch_coverage(bounds: @coverage_profile.bounding_box)
        return result unless result.success?

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
  end
end
