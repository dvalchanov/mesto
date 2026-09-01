require "rails_helper"

RSpec.describe "SofiaPlan data clients" do
  it "parses version and catalog fixtures without network access" do
    version = DataSources::Sofiaplan::CatalogClient.new.version
    catalog = DataSources::Sofiaplan::CatalogClient.new.datasets

    expect(version).to be_success
    expect(version.data).to eq("version" => "1.0")
    expect(catalog.data.map { |dataset| dataset["id"] }).to include(166, 142)
  end

  it "imports GeoJSON, preserves freshness, and skips an unchanged checksum" do
    SpatialDataset.find_by(key: "schools")&.destroy!
    config = DataSources.config.dig("sofiaplan", "datasets", "schools")
    result = DataSources::Sofiaplan::DatasetClient.new.fetch(config.fetch("id"))
    importer = DataSources::Sofiaplan::GeojsonImporter.new(
      dataset_config: config.merge("category" => "schools"), payload: result.data, source_url: result.source_url
    )

    first = importer.call
    second = importer.call

    expect(first.status).to eq("succeeded")
    expect(first.records_created).to eq(2)
    expect(first.spatial_dataset.relevant_at.to_date).to eq(Date.new(2018, 8, 8))
    expect(second.status).to eq("skipped")
  end

  it "returns an independent failure when one importer fails" do
    client = instance_double(DataSources::Sofiaplan::DatasetClient)
    allow(client).to receive(:fetch).and_return(
      DataSources::Result.success(
        data: { "type" => "FeatureCollection", "features" => [] },
        source_url: "https://api.sofiaplan.bg/datasets/166"
      )
    )
    allow(DataSources::Sofiaplan::GeojsonImporter).to receive(:new).and_raise(ActiveRecord::RecordInvalid)

    result = DataSources::Sofiaplan::DatasetSynchronizer.new(dataset_client: client).sync("schools").fetch("schools")

    expect(result.status).to eq(:failure)
  end
end
