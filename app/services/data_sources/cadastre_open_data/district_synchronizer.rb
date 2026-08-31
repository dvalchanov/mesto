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

      def initialize(client: ArchiveClient.new)
        @client = client
      end

      def sync_sofia_individual_objects(district, force: false)
        sync_archive(district, :individual_objects, force:)
      end

      def sync_sofia_property_hierarchy(district, identifier_level:, force: false)
        HIERARCHY_ARCHIVES.fetch(identifier_level).to_h do |archive_kind|
          [ archive_kind, sync_archive(district, archive_kind, force:) ]
        end
      end

      private

      def sync_archive(district, archive_kind, force:)
        district = normalize_district(district)
        raise ArgumentError, "A valid Sofia district is required" unless district

        archive_key = "#{SOFIA_ARCHIVE_PREFIX} #{district}/#{ARCHIVE_NAMES.fetch(archive_kind)}"
        existing = CadastreImport.where(
          source_archive_key: archive_key, status: "succeeded",
          importer_version: PropertyArchiveImporter::IMPORTER_VERSION
        )
          .order(completed_at: :desc).first
        return existing if existing && !force

        @client.download(archive_key) do |archive_path, source_url|
          return PropertyArchiveImporter.new(
            archive_path:, source_archive_key: archive_key, source_url:, archive_kind:
          ).call
        end
      end

      def normalize_district(value)
        district = value.to_s.strip.sub(/\A(?:СО\s*[-–]\s*)?(?:р-н|район)\s*/i, "")
        district if district.match?(/\A[\p{L}][\p{L}\s-]*\z/)
      end
    end
  end
end
