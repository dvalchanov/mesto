require "rails_helper"

RSpec.describe DataSources::OpenStreetMap::NearbyAmenitiesClient do
  let(:point) { RGeo::Geographic.spherical_factory(srid: 4326).point(23.3460262, 42.6394047) }

  it "returns a small, normalized set of nearby places with direct source links" do
    result = described_class.new.fetch(centroid: point)

    expect(result).to be_success
    expect(result.data.fetch("radius_m")).to eq(2_000)
    expect(result.data.fetch("features")).to include(
      include(
        "category" => "kindergartens",
        "name" => "ДГ №190",
        "distance_m" => be_between(290, 320),
        "source_url" => "https://www.openstreetmap.org/way/1256636075"
      )
    )
    expect(result.data.to_json).not_to include("nodes", "members")
  end

  it "uses one bounded query with a short server timeout" do
    allow(DataSources).to receive(:fixture?).and_return(false)
    http_client = instance_double(DataSources::HttpClient)
    response = instance_double(Faraday::Response, body: DataSources::FixtureLoader.read("openstreetmap_nearby_amenities.json"))
    endpoint = DataSources.config.dig("openstreetmap", "overpass_url")
    expect(http_client).to receive(:get) do |url, params|
      expect(url).to eq(endpoint)
      expect(params.fetch(:data)).to include(
        "[timeout:8]", "[maxsize:2097152]", "around:2000", "out center tags qt"
      )
      response
    end

    expect(described_class.new(http_client:).fetch(centroid: point)).to be_success
  end
end
