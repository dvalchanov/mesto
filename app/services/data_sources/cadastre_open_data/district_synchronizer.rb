module DataSources
  module CadastreOpenData
    class DistrictSynchronizer
      SOFIA_ARCHIVE_PREFIX = "област София (столица)/община Столична/гр. София (68134) - район".freeze
      ARCHIVE_NAMES = {
        parcels: "поземлени имоти.zip",
        buildings: "сгради.zip",
        individual_objects: "самостоятелни обекти.zip"
      }.freeze
      HIERARCHY_ARCHIVES = {
        "parcel" => %i[parcels],
        "building" => %i[parcels buildings],
        "individual_object" => %i[parcels buildings individual_objects]
      }.freeze

      def self.archive_key(district, archive_name)
        "#{SOFIA_ARCHIVE_PREFIX} #{district}/#{archive_name}"
      end

      def initialize(client: ArchiveClient.new, coverage_profile: DataCoverage.profile)
        @client = client
        @coverage_profile = coverage_profile
      end

      def sync_sofia_individual_objects(district, force: false)
        sync_archive(district, :individual_objects, force:)
      end

      def sync_sofia_property_hierarchy(district, identifier_level:, force: false)
        HIERARCHY_ARCHIVES.fetch(identifier_level).to_h do |archive_kind|
          [ archive_kind, sync_archive(district, archive_kind, force:) ]
        end
      end

      def sync_catalog_entry(entry)
        raise ArgumentError, "Archive belongs to another coverage profile" unless entry.coverage_profile_key == @coverage_profile.key

        sync_archive(entry.district, entry.object_kind.to_sym, force: true, catalog_entry: entry)
      end

      private

      def sync_archive(district, archive_kind, force:, catalog_entry: nil)
        district = normalize_district(district)
        raise ArgumentError, "A valid Sofia district is required" unless district

        archive_key = self.class.archive_key(district, ARCHIVE_NAMES.fetch(archive_kind))
        catalog_entry ||= SourceCatalog.new(profile: @coverage_profile).ensure_district_entries!(district)
          .find { |entry| entry.source_archive_key == archive_key }
        DataSources::PermissionGate.ensure_bulk_ingestion_allowed!(
          catalog_entry.permission_status,
          source: catalog_entry.source_archive_key
        )
        catalog_entry&.update!(status: "checking", last_checked_at: Time.current)

        @client.download(
          archive_key,
          etag: catalog_entry.metadata["etag"],
          last_modified_at: parse_time(catalog_entry.metadata["last_modified_at"])
        ) do |archive_path, source_url, source_metadata|
          if source_metadata&.fetch(:not_modified, false)
            result = catalog_entry.latest_successful_import
            raise "Source returned not-modified without a successful local import" unless result

            catalog_entry.update!(status: "ready", last_checked_at: Time.current)
            return result
          end
          result = PropertyArchiveImporter.new(
            archive_path:, source_archive_key: archive_key, source_url:, archive_kind:,
            coverage_profile: @coverage_profile, source_metadata:
          ).call
          catalog_entry&.update!(
            status: "ready",
            last_checked_at: Time.current,
            latest_successful_import: result.status == "succeeded" ? result : catalog_entry.latest_successful_import,
            metadata: catalog_entry.metadata.merge(
              "etag" => source_metadata&.dig(:etag),
              "last_modified_at" => source_metadata&.dig(:last_modified_at)&.iso8601
            ).compact
          )
          return result
        end
      rescue StandardError
        catalog_entry&.update!(status: "failed", last_checked_at: Time.current)
        raise
      end

      def normalize_district(value)
        district = value.to_s.strip.sub(/\A(?:СО\s*[-–]\s*)?(?:р-н|район)\s*/i, "")
        district if district.match?(/\A[\p{L}][\p{L}\s-]*\z/)
      end


      def parse_time(value)
        Time.iso8601(value) if value.present?
      rescue ArgumentError
        nil
      end
    end
  end
end
