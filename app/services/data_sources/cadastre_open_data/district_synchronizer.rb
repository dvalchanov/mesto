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

      def initialize(
        client: ArchiveClient.new,
        coverage_profile: DataCoverage.profile,
        archive_store: DataSources::SourceArchives.store
      )
        @client = client
        @coverage_profile = coverage_profile
        @archive_store = archive_store
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

      def replay_catalog_entry(entry)
        validate_catalog_entry!(entry)
        ensure_ingestion_allowed!(entry)
        artifact = @archive_store.latest(
          provider: "cadastre",
          source_key: entry.source_archive_key,
          coverage_profile_key: @coverage_profile.key
        )
        raise DataSources::SourceArchives::ConfigurationError, "No retained source archive is available" unless artifact

        entry.update!(status: "checking", last_checked_at: Time.current)
        replay_artifact(entry, artifact)
      rescue StandardError
        entry&.update!(status: "failed", last_checked_at: Time.current)
        raise
      end

      private

      def sync_archive(district, archive_kind, force:, catalog_entry: nil)
        district = normalize_district(district)
        raise ArgumentError, "A valid Sofia district is required" unless district

        archive_key = self.class.archive_key(district, ARCHIVE_NAMES.fetch(archive_kind))
        catalog_entry ||= SourceCatalog.new(profile: @coverage_profile).ensure_district_entries!(district)
          .find { |entry| entry.source_archive_key == archive_key }
        ensure_ingestion_allowed!(catalog_entry)
        catalog_entry&.update!(status: "checking", last_checked_at: Time.current)
        candidate = @archive_store.candidate(
          provider: "cadastre",
          source_key: archive_key,
          coverage_profile_key: @coverage_profile.key
        )

        @client.download(
          archive_key,
          etag: candidate&.source_etag || catalog_entry.metadata["etag"],
          last_modified_at: candidate&.source_last_modified_at || parse_time(catalog_entry.metadata["last_modified_at"])
        ) do |archive_path, source_url, source_metadata|
          if source_metadata&.fetch(:not_modified, false)
            if candidate
              candidate_metadata = artifact_metadata(candidate).merge(
                checked_at: source_metadata[:checked_at],
                etag: source_metadata[:etag] || candidate.source_etag,
                last_modified_at: source_metadata[:last_modified_at] || candidate.source_last_modified_at
              )
              return replay_artifact(catalog_entry, candidate, source_metadata: candidate_metadata)
            end

            result = catalog_entry.latest_successful_import
            raise "Source returned not-modified without a successful local import" unless result

            catalog_entry.update!(status: "ready", last_checked_at: Time.current)
            return result
          end
          artifact = @archive_store.stage_file(
            path: archive_path,
            provider: "cadastre",
            source_key: archive_key,
            coverage_profile_key: @coverage_profile.key,
            source_url:,
            fetched_at: source_metadata&.dig(:checked_at) || Time.current,
            content_type: source_metadata&.dig(:content_type) || "application/zip",
            extension: "zip",
            source_checksum: source_metadata&.dig(:checksum),
            source_etag: source_metadata&.dig(:etag),
            source_last_modified_at: source_metadata&.dig(:last_modified_at)
          )
          return import_and_promote(
            catalog_entry:, archive_path:, archive_kind:, source_url:, source_metadata:, artifact:
          )
        end
      rescue StandardError
        catalog_entry&.update!(status: "failed", last_checked_at: Time.current)
        raise
      end

      def normalize_district(value)
        district = value.to_s.strip.sub(/\A(?:СО\s*[-\u2013]\s*)?(?:р-н|район)\s*/i, "")
        district if district.match?(/\A[\p{L}][\p{L}\s-]*\z/)
      end

      def import_and_promote(catalog_entry:, archive_path:, archive_kind:, source_url:, source_metadata:, artifact:)
        result = PropertyArchiveImporter.new(
          archive_path:, source_archive_key: catalog_entry.source_archive_key, source_url:, archive_kind:,
          coverage_profile: @coverage_profile, source_metadata:
        ).call
        manifest = @archive_store.promote(
          artifact,
          database_import_id: result.id,
          importer_version: result.importer_version,
          relevant_at: result.relevant_at
        )
        metadata = catalog_entry.metadata.merge(
          "etag" => source_metadata&.dig(:etag),
          "last_modified_at" => source_metadata&.dig(:last_modified_at)&.iso8601
        ).compact
        metadata["retained_archive"] = manifest if manifest
        catalog_entry.update!(
          status: "ready",
          last_checked_at: Time.current,
          latest_successful_import: result.status == "succeeded" ? result : catalog_entry.latest_successful_import,
          metadata:
        )
        result
      end

      def replay_artifact(catalog_entry, artifact, source_metadata: artifact_metadata(artifact))
        @archive_store.with_file(artifact) do |archive_path|
          import_and_promote(
            catalog_entry:,
            archive_path:,
            archive_kind: catalog_entry.object_kind.to_sym,
            source_url: artifact.source_url,
            source_metadata:,
            artifact:
          )
        end
      end

      def artifact_metadata(artifact)
        {
          checked_at: artifact.fetched_at,
          checksum: artifact.source_checksum,
          byte_size: artifact.byte_size,
          content_type: artifact.content_type,
          etag: artifact.source_etag,
          last_modified_at: artifact.source_last_modified_at
        }
      end

      def validate_catalog_entry!(entry)
        return if entry.coverage_profile_key == @coverage_profile.key

        raise ArgumentError, "Archive belongs to another coverage profile"
      end

      def ensure_ingestion_allowed!(entry)
        DataSources::PermissionGate.ensure_bulk_ingestion_allowed!(
          entry.permission_status,
          source: entry.source_archive_key
        )
      end

      def parse_time(value)
        Time.iso8601(value) if value.present?
      rescue ArgumentError
        nil
      end
    end
  end
end
