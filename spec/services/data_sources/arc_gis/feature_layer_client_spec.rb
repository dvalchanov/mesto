require "rails_helper"

RSpec.describe DataSources::ArcGis::FeatureLayerClient do
  let(:layer_url) { DataSources.config.dig("arcgis", "development_potential", "url") }
  let(:client) { described_class.new(layer_url:) }
  let(:point) { RGeo::Geographic.spherical_factory(srid: 4326).point(23.32, 42.69) }

  it "returns the fixture GeoJSON" do
    result = client.query(geometry: point)

    expect(result).to be_success
    expect(result.data.fetch("features").length).to eq(1)
  end

  it "paginates beyond MaxRecordCount in live mode" do
    allow(DataSources).to receive(:fixture?).and_return(false)
    stub_request(:get, layer_url).with(query: { "f" => "json" }).to_return(
      body: { maxRecordCount: 1 }.to_json, headers: { "Content-Type" => "application/json" }
    )
    responses = [
      { type: "FeatureCollection", features: [ { type: "Feature", properties: { id: 1 }, geometry: nil } ], exceededTransferLimit: true },
      { type: "FeatureCollection", features: [ { type: "Feature", properties: { id: 2 }, geometry: nil } ], exceededTransferLimit: false }
    ]
    stub_request(:get, %r{#{Regexp.escape(layer_url)}/query}).to_return(*responses.map { |body| { body: body.to_json } })

    result = client.query(geometry: point)

    expect(result).to be_success
    expect(result.data.fetch("features").pluck("properties").pluck("id")).to eq([ 1, 2 ])
  end

  it "supports an empty result" do
    allow(DataSources::FixtureLoader).to receive(:read).with("arcgis_geojson.json").and_return(
      { type: "FeatureCollection", features: [] }.to_json
    )

    expect(client.query(geometry: point).data.fetch("features")).to be_empty
  end
end
