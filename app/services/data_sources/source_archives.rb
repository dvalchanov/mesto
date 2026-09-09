module DataSources
  module SourceArchives
    class ConfigurationError < StandardError; end
    class IntegrityError < StandardError; end

    def self.store
      @store ||= build
    end

    def self.build(env: ENV, client: nil)
      bucket = env["SOURCE_ARCHIVE_BUCKET"].presence
      required = ActiveModel::Type::Boolean.new.cast(
        env.fetch("SOURCE_ARCHIVE_REQUIRED", Rails.env.production?.to_s)
      )

      if bucket.blank?
        raise ConfigurationError, "SOURCE_ARCHIVE_BUCKET is required for production ingestion" if required

        return NullStore.new
      end

      S3Store.new(
        bucket:,
        region: env.fetch("SOURCE_ARCHIVE_REGION", "eu-west-1"),
        prefix: env.fetch("SOURCE_ARCHIVE_PREFIX", Rails.env),
        expected_bucket_owner: env["SOURCE_ARCHIVE_EXPECTED_BUCKET_OWNER"].presence,
        multipart_threshold: env.fetch("SOURCE_ARCHIVE_MULTIPART_THRESHOLD_BYTES", 100.megabytes).to_i,
        upload_threads: env.fetch("SOURCE_ARCHIVE_UPLOAD_THREADS", 1).to_i,
        client:
      )
    end

    def self.reset!
      @store = nil
    end

    def self.import_json(store:, result:, provider:, source_key:, coverage_profile:)
      artifact = store.stage_json(
        payload: result.data,
        provider:,
        source_key:,
        coverage_profile_key: coverage_profile.key,
        source_url: result.source_url,
        fetched_at: result.fetched_at,
        relevant_at: result.relevant_at
      )
      database_import = yield
      if artifact && database_import.checksum != artifact.source_checksum
        raise IntegrityError, "Database import checksum does not match the retained JSON source"
      end

      store.promote(
        artifact,
        database_import_id: database_import.id,
        importer_version: database_import.importer_version,
        relevant_at: database_import.relevant_at
      )
      database_import
    end

    def self.replay_json(store:, provider:, source_key:, coverage_profile:)
      artifact = store.latest(
        provider:,
        source_key:,
        coverage_profile_key: coverage_profile.key
      )
      raise ConfigurationError, "No retained source archive is available" unless artifact

      Result.success(
        data: store.read_json(artifact),
        source_url: artifact.source_url,
        fetched_at: artifact.fetched_at,
        relevant_at: artifact.relevant_at
      )
    end
  end
end
