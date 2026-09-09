require "rails_helper"

RSpec.describe DataSources::SourceArchives do
  describe ".build" do
    it "uses a no-op store when archives are optional and no bucket is configured" do
      store = described_class.build(env: { "SOURCE_ARCHIVE_REQUIRED" => "false" })

      expect(store).to be_a(DataSources::SourceArchives::NullStore)
      expect(store).not_to be_enabled
    end

    it "fails closed when archives are required and no bucket is configured" do
      expect {
        described_class.build(env: { "SOURCE_ARCHIVE_REQUIRED" => "true" })
      }.to raise_error(DataSources::SourceArchives::ConfigurationError, /SOURCE_ARCHIVE_BUCKET/)
    end

    it "builds an S3 store without requiring explicit AWS keys" do
      client = Aws::S3::Client.new(region: "eu-west-1", stub_responses: true)
      store = described_class.build(
        env: {
          "SOURCE_ARCHIVE_BUCKET" => "mesto-source-archives",
          "SOURCE_ARCHIVE_REGION" => "eu-west-1",
          "SOURCE_ARCHIVE_PREFIX" => "staging"
        },
        client:
      )

      expect(store).to be_a(DataSources::SourceArchives::S3Store)
      expect(store).to be_enabled
    end
  end


  describe ".import_json" do
    let(:profile) { DataCoverage.profile }
    let(:payload) { { "type" => "FeatureCollection", "features" => [] } }
    let(:result) do
      DataSources::Result.success(
        data: payload,
        source_url: "https://example.test/dataset",
        fetched_at: Time.zone.parse("2026-09-09 03:00:00")
      )
    end
    let(:artifact) do
      instance_double(
        DataSources::SourceArchives::Artifact,
        source_checksum: Digest::SHA256.hexdigest(DataSources::SourceArchives::CanonicalJson.dump(payload))
      )
    end
    let(:archive_store) { instance_double(DataSources::SourceArchives::S3Store) }
    let(:database_import) do
      instance_double(
        DatasetImport,
        id: 42,
        status: "succeeded",
        checksum: artifact.source_checksum,
        importer_version: 2,
        relevant_at: nil
      )
    end

    it "stages before import and promotes only after the database import succeeds" do
      events = []
      allow(archive_store).to receive(:stage_json) do
        events << :stage
        artifact
      end
      allow(archive_store).to receive(:promote) { events << :promote }

      described_class.import_json(
        store: archive_store,
        result:,
        provider: "sofiaplan",
        source_key: "schools",
        coverage_profile: profile
      ) do
        events << :import
        database_import
      end

      expect(events).to eq(%i[stage import promote])
      expect(archive_store).to have_received(:promote).with(
        artifact,
        database_import_id: 42,
        importer_version: 2,
        relevant_at: nil
      )
    end

    it "does not promote when database publication fails" do
      allow(archive_store).to receive(:stage_json).and_return(artifact)
      expect(archive_store).not_to receive(:promote)

      expect {
        described_class.import_json(
          store: archive_store,
          result:,
          provider: "sofiaplan",
          source_key: "schools",
          coverage_profile: profile
        ) { raise ActiveRecord::Rollback, "publication failed" }
      }.to raise_error(ActiveRecord::Rollback)
    end

    it "refuses to promote when S3 and database checksums differ" do
      allow(archive_store).to receive(:stage_json).and_return(artifact)
      allow(database_import).to receive(:checksum).and_return("different")
      expect(archive_store).not_to receive(:promote)

      expect {
        described_class.import_json(
          store: archive_store,
          result:,
          provider: "sofiaplan",
          source_key: "schools",
          coverage_profile: profile
        ) { database_import }
      }.to raise_error(DataSources::SourceArchives::IntegrityError, /checksum/)
    end
  end

  describe ".replay_json" do
    it "reconstructs a source result entirely from the retained artifact" do
      profile = DataCoverage.profile
      artifact = instance_double(
        DataSources::SourceArchives::Artifact,
        source_url: "https://example.test/dataset",
        fetched_at: Time.zone.parse("2026-09-09 03:00:00"),
        relevant_at: Time.zone.parse("2026-09-01")
      )
      archive_store = instance_double(DataSources::SourceArchives::S3Store)
      expect(archive_store).to receive(:latest).with(
        provider: "sofiaplan",
        source_key: "schools",
        coverage_profile_key: profile.key
      ).and_return(artifact)
      expect(archive_store).to receive(:read_json).with(artifact).and_return(
        "type" => "FeatureCollection", "features" => []
      )

      result = described_class.replay_json(
        store: archive_store,
        provider: "sofiaplan",
        source_key: "schools",
        coverage_profile: profile
      )

      expect(result).to be_success
      expect(result.data).to eq("type" => "FeatureCollection", "features" => [])
      expect(result.source_url).to eq("https://example.test/dataset")
    end
  end
end
