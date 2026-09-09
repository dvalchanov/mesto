require "rails_helper"

RSpec.describe DataSources::CadastreOpenData::DistrictSynchronizer do
  let(:profile) { instance_double(DataCoverage::Profile, key: "test_fixtures") }
  let(:archive_key) do
    described_class.archive_key("Студентски", described_class::ARCHIVE_NAMES.fetch(:parcels))
  end
  let(:entry) do
    instance_double(
      CadastreSourceArchive,
      coverage_profile_key: profile.key,
      district: "Студентски",
      object_kind: "parcels",
      source_archive_key: archive_key,
      permission_status: "approved",
      metadata: {},
      latest_successful_import: nil
    )
  end
  let(:client) { instance_double(DataSources::CadastreOpenData::ArchiveClient) }
  let(:archive_store) { instance_double(DataSources::SourceArchives::S3Store) }
  let(:artifact) do
    DataSources::SourceArchives::Artifact.new(
      provider: "cadastre",
      source_key: archive_key,
      coverage_profile_key: profile.key,
      object_key: "test/objects/cadastre/archive.zip",
      source_checksum: Digest::SHA256.hexdigest("archive"),
      object_checksum: Digest::SHA256.hexdigest("archive"),
      byte_size: 7,
      content_type: "application/zip",
      content_encoding: nil,
      source_url: "https://example.test/archive.zip",
      fetched_at: Time.zone.parse("2026-09-09 03:00:00"),
      relevant_at: nil,
      source_etag: '"v1"',
      source_last_modified_at: Time.zone.parse("2026-09-08 03:00:00")
    )
  end
  let(:database_import) do
    instance_double(
      CadastreImport,
      id: 42,
      status: "succeeded",
      importer_version: 3,
      relevant_at: Time.zone.parse("2026-09-01")
    )
  end
  let(:importer) { instance_double(DataSources::CadastreOpenData::PropertyArchiveImporter) }
  let(:manifest) { { "object_key" => artifact.object_key, "database_import_id" => 42 } }

  before do
    allow(entry).to receive(:update!)
    allow(archive_store).to receive(:candidate).and_return(nil)
    allow(archive_store).to receive(:stage_file)
    allow(importer).to receive(:call).and_return(database_import)
    allow(DataSources::CadastreOpenData::PropertyArchiveImporter).to receive(:new).and_return(importer)
  end

  it "stages the ZIP before import and promotes it only after publication" do
    source_metadata = {
      checked_at: artifact.fetched_at,
      checksum: artifact.source_checksum,
      byte_size: artifact.byte_size,
      content_type: artifact.content_type,
      etag: artifact.source_etag,
      last_modified_at: artifact.source_last_modified_at,
      not_modified: false
    }
    events = []
    allow(client).to receive(:download) do |_key, **, &block|
      Tempfile.create([ "district", ".zip" ]) do |file|
        file.write("archive")
        file.flush
        block.call(file.path, artifact.source_url, source_metadata)
      end
    end
    allow(archive_store).to receive(:stage_file) do
      events << :stage
      artifact
    end
    allow(importer).to receive(:call) do
      events << :import
      database_import
    end
    allow(archive_store).to receive(:promote) do
      events << :promote
      manifest
    end

    result = described_class.new(client:, coverage_profile: profile, archive_store:).sync_catalog_entry(entry)

    expect(result).to eq(database_import)
    expect(events).to eq(%i[stage import promote])
    expect(archive_store).to have_received(:stage_file).with(
      hash_including(source_checksum: artifact.source_checksum, extension: "zip")
    )
    expect(entry).to have_received(:update!).with(
      hash_including(status: "ready", latest_successful_import: database_import)
    )
  end


  it "reuses a matching failed candidate after an upstream not-modified response" do
    source_metadata = { checked_at: Time.current, not_modified: true }
    allow(archive_store).to receive(:candidate).and_return(artifact)
    allow(client).to receive(:download) do |_key, **options, &block|
      expect(options.fetch(:etag)).to eq(artifact.source_etag)
      block.call(nil, artifact.source_url, source_metadata)
    end
    allow(archive_store).to receive(:with_file) do |_artifact, &block|
      Tempfile.create([ "candidate", ".zip" ]) do |file|
        file.write("archive")
        file.flush
        block.call(file.path)
      end
    end
    allow(archive_store).to receive(:promote).and_return(manifest)

    result = described_class.new(client:, coverage_profile: profile, archive_store:).sync_catalog_entry(entry)

    expect(result).to eq(database_import)
    expect(archive_store).to have_received(:with_file).with(artifact)
    expect(archive_store).not_to have_received(:stage_file)
  end

  it "replays and verifies the retained ZIP without using the upstream client" do
    allow(archive_store).to receive(:latest).and_return(artifact)
    allow(archive_store).to receive(:with_file) do |_artifact, &block|
      Tempfile.create([ "replay", ".zip" ]) do |file|
        file.write("archive")
        file.flush
        block.call(file.path)
      end
    end
    allow(archive_store).to receive(:promote).and_return(manifest)
    expect(client).not_to receive(:download)

    result = described_class.new(client:, coverage_profile: profile, archive_store:).replay_catalog_entry(entry)

    expect(result).to eq(database_import)
    expect(archive_store).to have_received(:with_file).with(artifact)
  end
end
