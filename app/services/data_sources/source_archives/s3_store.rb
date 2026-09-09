require "aws-sdk-s3"
require "zlib"

module DataSources
  module SourceArchives
    class S3Store
      CANDIDATE_TAG = "candidate".freeze
      CURRENT_TAG = "current".freeze
      ROLLBACK_TAG = "rollback".freeze

      def initialize(
        bucket:, region:, prefix:, expected_bucket_owner: nil,
        multipart_threshold: 100.megabytes, upload_threads: 1, client: nil
      )
        @bucket = bucket
        @prefix = prefix.to_s.delete_prefix("/").delete_suffix("/").presence
        @expected_bucket_owner = expected_bucket_owner
        @multipart_threshold = Integer(multipart_threshold)
        @upload_threads = Integer(upload_threads)
        @client = client || Aws::S3::Client.new(region:)
        @transfer_manager = Aws::S3::TransferManager.new(client: @client)
      end

      def enabled? = true

      def stage_file(
        path:, provider:, source_key:, coverage_profile_key:, source_url:, fetched_at:,
        content_type:, extension:, source_checksum: nil, relevant_at: nil, source_etag: nil,
        source_last_modified_at: nil
      )
        path = Pathname(path)
        object_checksum = Digest::SHA256.file(path).hexdigest
        source_checksum ||= object_checksum
        if source_checksum != object_checksum
          raise IntegrityError, "The supplied source checksum does not match the source artifact"
        end

        store_file(
          path:, provider:, source_key:, coverage_profile_key:, source_url:, fetched_at:,
          content_type:, extension:, source_checksum:, object_checksum:, relevant_at:,
          source_etag:, source_last_modified_at:
        )
      end

      def stage_json(
        payload:, provider:, source_key:, coverage_profile_key:, source_url:, fetched_at:,
        relevant_at: nil, source_etag: nil, source_last_modified_at: nil
      )
        canonical_json = CanonicalJson.dump(payload)
        source_checksum = Digest::SHA256.hexdigest(canonical_json)

        Tempfile.create([ "mesto-source-archive", ".json.gz" ]) do |tempfile|
          tempfile.binmode
          gzip = Zlib::GzipWriter.new(tempfile)
          gzip.mtime = 0
          gzip.write(canonical_json)
          gzip.close

          store_file(
            path: Pathname(tempfile.path), provider:, source_key:, coverage_profile_key:,
            source_url:, fetched_at:, content_type: "application/geo+json", extension: "json.gz",
            source_checksum:, object_checksum: Digest::SHA256.file(tempfile.path).hexdigest,
            content_encoding: "gzip", relevant_at:, source_etag:, source_last_modified_at:
          )
        end
      end

      def latest(provider:, source_key:, coverage_profile_key:)
        manifest = latest_manifest(provider:, source_key:, coverage_profile_key:)
        return unless manifest

        artifact = Artifact.from_manifest(manifest)
        verify_identity!(artifact, provider:, source_key:, coverage_profile_key:)
        artifact
      end

      def candidate(provider:, source_key:, coverage_profile_key:)
        manifest = read_manifest(
          candidate_manifest_key(provider:, source_key:, coverage_profile_key:)
        )
        return unless manifest

        artifact = Artifact.from_manifest(manifest)
        verify_identity!(artifact, provider:, source_key:, coverage_profile_key:)
        artifact
      end

      def promote(artifact, database_import_id:, importer_version:, relevant_at: nil)
        return unless artifact

        previous_manifest = latest_manifest(
          provider: artifact.provider,
          source_key: artifact.source_key,
          coverage_profile_key: artifact.coverage_profile_key
        )
        previous = Artifact.from_manifest(previous_manifest) if previous_manifest
        verify_identity!(
          previous,
          provider: artifact.provider,
          source_key: artifact.source_key,
          coverage_profile_key: artifact.coverage_profile_key
        ) if previous
        rollback_object_key = if previous && previous.object_key != artifact.object_key
          previous.object_key
        else
          previous_manifest&.fetch("rollback_object_key", nil)
        end
        tag(artifact.object_key, CURRENT_TAG)

        manifest = artifact.manifest(
          database_import_id:, importer_version:, promoted_at: Time.current, relevant_at:
        )
        manifest["rollback_object_key"] = rollback_object_key if rollback_object_key
        @client.put_object(
          request_options(
            key: manifest_key(
              provider: artifact.provider,
              source_key: artifact.source_key,
              coverage_profile_key: artifact.coverage_profile_key
            ),
            body: JSON.generate(manifest),
            content_type: "application/json",
            cache_control: "no-store",
            checksum_algorithm: "SHA256",
            server_side_encryption: "AES256",
            tagging: tag_query("manifest")
          )
        )
        tag(previous.object_key, ROLLBACK_TAG) if previous && previous.object_key != artifact.object_key
        retire_previous_rollback(previous_manifest, except: rollback_object_key)
        @client.delete_object(
          request_options(
            key: candidate_manifest_key(
              provider: artifact.provider,
              source_key: artifact.source_key,
              coverage_profile_key: artifact.coverage_profile_key
            )
          )
        )
        manifest
      end

      def with_file(artifact)
        Tempfile.create([ "mesto-source-replay", File.extname(artifact.object_key) ]) do |tempfile|
          tempfile.close
          @transfer_manager.download_file(
            tempfile.path,
            bucket: @bucket,
            key: artifact.object_key,
            thread_count: 1,
            **owner_option
          )
          checksum = Digest::SHA256.file(tempfile.path).hexdigest
          raise IntegrityError, "Downloaded source archive checksum mismatch" unless checksum == artifact.object_checksum

          yield tempfile.path
        end
      end

      def read_json(artifact)
        with_file(artifact) do |path|
          Zlib::GzipReader.open(path) { |gzip| JSON.parse(gzip.read) }
        end
      end

      private

      def latest_manifest(provider:, source_key:, coverage_profile_key:)
        read_manifest(manifest_key(provider:, source_key:, coverage_profile_key:))
      end

      def read_manifest(key)
        response = @client.get_object(request_options(key:))
        JSON.parse(response.body.read)
      rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
        nil
      end

      def store_file(
        path:, provider:, source_key:, coverage_profile_key:, source_url:, fetched_at:,
        content_type:, extension:, source_checksum:, object_checksum:, content_encoding: nil,
        relevant_at: nil, source_etag: nil, source_last_modified_at: nil
      )
        key = object_key(
          provider:, source_key:, coverage_profile_key:, source_checksum:, extension:
        )
        artifact = Artifact.new(
          provider:, source_key:, coverage_profile_key:, object_key: key, source_checksum:,
          object_checksum:, byte_size: File.size(path), content_type:, content_encoding:,
          source_url:, fetched_at:, relevant_at:, source_etag:, source_last_modified_at:
        )
        unless stored?(artifact)
          options = {
            multipart_threshold: @multipart_threshold,
            thread_count: @upload_threads,
            checksum_algorithm: "SHA256",
            content_type:,
            content_encoding:,
            server_side_encryption: "AES256",
            metadata: {
              "source-checksum" => source_checksum,
              "object-checksum" => object_checksum
            },
            tagging: tag_query(CANDIDATE_TAG)
          }.compact.merge(owner_option)
          @transfer_manager.upload_file(path, bucket: @bucket, key:, **options)
        end
        write_candidate_manifest(artifact)
        artifact
      end

      def write_candidate_manifest(artifact)
        manifest = artifact.manifest(
          database_import_id: nil,
          importer_version: nil,
          promoted_at: Time.current
        ).merge("status" => CANDIDATE_TAG)
        @client.put_object(
          request_options(
            key: candidate_manifest_key(
              provider: artifact.provider,
              source_key: artifact.source_key,
              coverage_profile_key: artifact.coverage_profile_key
            ),
            body: JSON.generate(manifest),
            content_type: "application/json",
            cache_control: "no-store",
            checksum_algorithm: "SHA256",
            server_side_encryption: "AES256",
            tagging: tag_query(CANDIDATE_TAG)
          )
        )
      end

      def stored?(artifact)
        response = @client.head_object(request_options(key: artifact.object_key))
        matches = response.content_length == artifact.byte_size &&
          response.metadata["source-checksum"] == artifact.source_checksum &&
          response.metadata["object-checksum"] == artifact.object_checksum
        raise IntegrityError, "Stored source archive metadata does not match its checksum key" unless matches

        true
      rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
        false
      end

      def tag(key, value)
        @client.put_object_tagging(
          request_options(
            key:,
            tagging: { tag_set: [ { key: "mesto-retention", value: } ] }
          )
        )
      end

      def retire_previous_rollback(previous_manifest, except:)
        key = previous_manifest&.fetch("rollback_object_key", nil)
        return if key.blank? || key == except

        @client.delete_object(request_options(key:))
      end

      def verify_identity!(artifact, provider:, source_key:, coverage_profile_key:)
        return if artifact.provider == provider && artifact.source_key == source_key &&
          artifact.coverage_profile_key == coverage_profile_key

        raise IntegrityError, "Latest source archive manifest identity mismatch"
      end

      def object_key(provider:, source_key:, coverage_profile_key:, source_checksum:, extension:)
        join_prefix(
          "objects",
          safe_segment(provider),
          Digest::SHA256.hexdigest(source_key)[0, 24],
          Digest::SHA256.hexdigest(coverage_profile_key)[0, 24],
          "#{source_checksum}.#{extension.to_s.delete_prefix('.')}"
        )
      end

      def manifest_key(provider:, source_key:, coverage_profile_key:)
        join_prefix(
          "latest",
          safe_segment(provider),
          Digest::SHA256.hexdigest(source_key)[0, 24],
          "#{Digest::SHA256.hexdigest(coverage_profile_key)[0, 24]}.json"
        )
      end

      def candidate_manifest_key(provider:, source_key:, coverage_profile_key:)
        join_prefix(
          "candidates",
          safe_segment(provider),
          Digest::SHA256.hexdigest(source_key)[0, 24],
          "#{Digest::SHA256.hexdigest(coverage_profile_key)[0, 24]}.json"
        )
      end

      def safe_segment(value)
        value.to_s.downcase.gsub(/[^a-z0-9_-]+/, "-").delete_prefix("-").delete_suffix("-").presence || "source"
      end

      def join_prefix(*segments)
        [ @prefix, *segments ].compact.join("/")
      end

      def request_options(**options)
        options.merge(bucket: @bucket, **owner_option)
      end

      def owner_option
        @expected_bucket_owner ? { expected_bucket_owner: @expected_bucket_owner } : {}
      end

      def tag_query(value)
        URI.encode_www_form("mesto-retention" => value)
      end
    end
  end
end
