require "rails_helper"

RSpec.describe DataSources::SourceArchives::S3Store do
  let(:client) { Aws::S3::Client.new(region: "eu-west-1", stub_responses: true) }
  let(:store) do
    described_class.new(
      bucket: "mesto-source-archives",
      region: "eu-west-1",
      prefix: "test",
      expected_bucket_owner: "123456789012",
      upload_threads: 1,
      client:
    )
  end
  let(:source_attributes) do
    {
      provider: "cadastre",
      source_key: "district/parcels.zip",
      coverage_profile_key: "sofia",
      source_url: "https://example.test/parcels.zip",
      fetched_at: Time.zone.parse("2026-09-09 03:00:00")
    }
  end

  describe "staging" do
    it "uploads a checksum-addressed, encrypted candidate with one transfer thread" do
      client.stub_responses(:head_object, "NotFound")

      with_tempfile("archive contents") do |path|
        artifact = store.stage_file(
          path:,
          **source_attributes,
          content_type: "application/zip",
          extension: "zip"
        )

        expect(artifact.source_checksum).to eq(Digest::SHA256.hexdigest("archive contents"))
        expect(artifact.object_key).to end_with("/#{artifact.source_checksum}.zip")
      end

      upload = object_uploads.sole.fetch(:params)
      expect(upload).to include(
        bucket: "mesto-source-archives",
        expected_bucket_owner: "123456789012",
        server_side_encryption: "AES256",
        checksum_algorithm: "SHA256",
        tagging: "mesto-retention=candidate"
      )
      expect(upload.fetch(:metadata)).to include("source-checksum", "object-checksum")
      candidate_manifest = api_requests(:put_object).find do |request|
        request.dig(:params, :key).include?("/candidates/")
      end
      expect(candidate_manifest.fetch(:params)).to include(
        cache_control: "no-store",
        tagging: "mesto-retention=candidate"
      )
    end

    it "reuses an object whose length and checksum metadata already match" do
      checksum = Digest::SHA256.hexdigest("archive contents")
      client.stub_responses(
        :head_object,
        content_length: "archive contents".bytesize,
        metadata: { "source-checksum" => checksum, "object-checksum" => checksum }
      )

      with_tempfile("archive contents") do |path|
        store.stage_file(
          path:,
          **source_attributes,
          content_type: "application/zip",
          extension: "zip",
          source_checksum: checksum
        )
      end

      expect(object_uploads).to be_empty
      expect(api_requests(:put_object).length).to eq(1)
    end

    it "rejects a checksum-key collision with mismatched stored metadata" do
      client.stub_responses(:head_object, content_length: 1, metadata: {})

      expect {
        with_tempfile("archive contents") do |path|
          store.stage_file(
            path:,
            **source_attributes,
            content_type: "application/zip",
            extension: "zip"
          )
        end
      }.to raise_error(DataSources::SourceArchives::IntegrityError)
    end

    it "compresses canonical JSON deterministically" do
      client.stub_responses(:head_object, "NotFound")
      first = store.stage_json(
        payload: { "features" => [ { "b" => 2, "a" => 1 } ], "type" => "FeatureCollection" },
        **source_attributes.except(:provider),
        provider: "sofiaplan"
      )
      client.stub_responses(
        :head_object,
        content_length: first.byte_size,
        metadata: {
          "source-checksum" => first.source_checksum,
          "object-checksum" => first.object_checksum
        }
      )
      second = store.stage_json(
        payload: { "type" => "FeatureCollection", "features" => [ { "a" => 1, "b" => 2 } ] },
        **source_attributes.except(:provider),
        provider: "sofiaplan"
      )

      expect(second.source_checksum).to eq(first.source_checksum)
      expect(second.object_checksum).to eq(first.object_checksum)
      expect(second.content_encoding).to eq("gzip")
      expect(object_uploads.length).to eq(1)
    end

    it "aborts an interrupted multipart upload without publishing a manifest" do
      client.stub_responses(:head_object, "NotFound")
      client.stub_responses(:create_multipart_upload, upload_id: "upload-1")
      client.stub_responses(:upload_part, "InternalError")
      multipart_store = described_class.new(
        bucket: "mesto-source-archives",
        region: "eu-west-1",
        prefix: "test",
        multipart_threshold: 5.megabytes,
        upload_threads: 1,
        client:
      )

      Tempfile.create([ "source-archive", ".zip" ]) do |file|
        file.binmode
        file.truncate(5.megabytes)
        file.flush

        expect {
          multipart_store.stage_file(
            path: file.path,
            **source_attributes,
            content_type: "application/zip",
            extension: "zip"
          )
        }.to raise_error(Aws::S3::MultipartUploadError)
      end

      expect(api_requests(:abort_multipart_upload).length).to eq(1)
      expect(api_requests(:put_object)).to be_empty
    end
  end

  describe "promotion" do
    it "publishes the latest manifest only after tagging the validated object" do
      client.stub_responses(:get_object, "NoSuchKey")
      artifact = build_artifact

      manifest = store.promote(
        artifact,
        database_import_id: 42,
        importer_version: 3,
        relevant_at: Time.zone.parse("2026-09-01")
      )

      operations = client.api_requests.map { |request| request.fetch(:operation_name) }
      expect(operations).to eq(%i[get_object put_object_tagging put_object delete_object])
      expect(manifest).to include(
        "object_key" => artifact.object_key,
        "database_import_id" => 42,
        "importer_version" => 3
      )
      expect(api_requests(:put_object).sole.dig(:params, :cache_control)).to eq("no-store")
    end

    it "marks the previous current object for rollback retention" do
      previous = build_artifact(object_key: "test/objects/cadastre/old.zip")
      client.stub_responses(
        :get_object,
        body: JSON.generate(
          previous.manifest(database_import_id: 1, importer_version: 3, promoted_at: 1.day.ago)
        )
      )
      current = build_artifact

      store.promote(current, database_import_id: 2, importer_version: 3)

      tag_requests = api_requests(:put_object_tagging)
      expect(tag_requests.map { |request| request.dig(:params, :key) }).to eq(
        [ current.object_key, previous.object_key ]
      )
      expect(tag_requests.last.dig(:params, :tagging, :tag_set)).to contain_exactly(
        key: "mesto-retention", value: "rollback"
      )
    end

    it "deletes an older rollback object when a new one replaces it" do
      previous = build_artifact(object_key: "test/objects/cadastre/previous.zip")
      previous_manifest = previous.manifest(
        database_import_id: 2,
        importer_version: 3,
        promoted_at: 1.day.ago
      ).merge("rollback_object_key" => "test/objects/cadastre/oldest.zip")
      client.stub_responses(:get_object, body: JSON.generate(previous_manifest))

      manifest = store.promote(build_artifact, database_import_id: 3, importer_version: 3)

      expect(manifest.fetch("rollback_object_key")).to eq(previous.object_key)
      expect(api_requests(:delete_object).map { |request| request.dig(:params, :key) }).to include(
        "test/objects/cadastre/oldest.zip"
      )
    end
  end

  describe "replay" do
    it "downloads and verifies the retained object before yielding it" do
      artifact = build_artifact(
        object_checksum: Digest::SHA256.hexdigest("retained archive"),
        byte_size: "retained archive".bytesize
      )
      client.stub_responses(:head_object, content_length: artifact.byte_size)
      client.stub_responses(:get_object, body: "retained archive")

      contents = store.with_file(artifact) { |path| File.binread(path) }

      expect(contents).to eq("retained archive")
    end

    it "rejects a corrupt download" do
      artifact = build_artifact
      client.stub_responses(:head_object, content_length: "corrupt".bytesize)
      client.stub_responses(:get_object, body: "corrupt")

      expect { store.with_file(artifact) { } }
        .to raise_error(DataSources::SourceArchives::IntegrityError, /checksum mismatch/)
    end
  end

  def with_tempfile(contents)
    Tempfile.create([ "source-archive", ".zip" ]) do |file|
      file.binmode
      file.write(contents)
      file.flush
      yield file.path
    end
  end

  def api_requests(operation)
    client.api_requests.select { |request| request.fetch(:operation_name) == operation }
  end

  def object_uploads
    api_requests(:put_object).select { |request| request.dig(:params, :key).include?("/objects/") }
  end

  def build_artifact(overrides = {})
    defaults = source_attributes.merge(
      object_key: "test/objects/cadastre/current.zip",
      source_checksum: Digest::SHA256.hexdigest("archive contents"),
      object_checksum: Digest::SHA256.hexdigest("archive contents"),
      byte_size: "archive contents".bytesize,
      content_type: "application/zip",
      content_encoding: nil,
      relevant_at: nil,
      source_etag: '"v1"',
      source_last_modified_at: Time.zone.parse("2026-09-08 03:00:00")
    )
    DataSources::SourceArchives::Artifact.new(**defaults.merge(overrides))
  end
end
