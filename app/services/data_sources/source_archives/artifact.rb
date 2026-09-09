module DataSources
  module SourceArchives
    Artifact = Data.define(
      :provider,
      :source_key,
      :coverage_profile_key,
      :object_key,
      :source_checksum,
      :object_checksum,
      :byte_size,
      :content_type,
      :content_encoding,
      :source_url,
      :fetched_at,
      :relevant_at,
      :source_etag,
      :source_last_modified_at
    ) do
      def manifest(database_import_id:, importer_version:, promoted_at:, relevant_at: nil)
        {
          "version" => 1,
          "provider" => provider,
          "source_key" => source_key,
          "coverage_profile_key" => coverage_profile_key,
          "object_key" => object_key,
          "source_checksum" => source_checksum,
          "object_checksum" => object_checksum,
          "byte_size" => byte_size,
          "content_type" => content_type,
          "content_encoding" => content_encoding,
          "source_url" => source_url,
          "fetched_at" => fetched_at&.iso8601,
          "relevant_at" => (relevant_at || self.relevant_at)&.iso8601,
          "source_etag" => source_etag,
          "source_last_modified_at" => source_last_modified_at&.iso8601,
          "database_import_id" => database_import_id,
          "importer_version" => importer_version,
          "promoted_at" => promoted_at.iso8601
        }.compact
      end

      def self.from_manifest(manifest)
        new(
          provider: manifest.fetch("provider"),
          source_key: manifest.fetch("source_key"),
          coverage_profile_key: manifest.fetch("coverage_profile_key"),
          object_key: manifest.fetch("object_key"),
          source_checksum: manifest.fetch("source_checksum"),
          object_checksum: manifest.fetch("object_checksum"),
          byte_size: manifest.fetch("byte_size"),
          content_type: manifest.fetch("content_type"),
          content_encoding: manifest["content_encoding"],
          source_url: manifest.fetch("source_url"),
          fetched_at: parse_time(manifest["fetched_at"]),
          relevant_at: parse_time(manifest["relevant_at"]),
          source_etag: manifest["source_etag"],
          source_last_modified_at: parse_time(manifest["source_last_modified_at"])
        )
      end

      def self.parse_time(value)
        Time.iso8601(value) if value.present?
      end
      private_class_method :parse_time
    end
  end
end
