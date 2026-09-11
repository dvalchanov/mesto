require "rails_helper"

RSpec.describe PropertyFinder::BuildingMap do
  let(:factory) { RGeo::Cartesian.preferred_factory(srid: 4326) }
  let(:source) do
    {
      identifier_level: "building",
      source_archive_key: "test/buildings.zip",
      source_url: "https://kais.cadastre.bg/bg/OpenData"
    }
  end

  before do
    CadastralProperty.create!(
      **source,
      cadastral_identifier: "68134.1609.4464.1",
      address: "гр. София, ул. Тестова №25",
      street_number: "25",
      objects_count: 1,
      geometry: factory.parse_wkt("POLYGON((23.340 42.640,23.341 42.640,23.341 42.641,23.340 42.641,23.340 42.640))")
    )
    CadastralProperty.create!(
      **source,
      cadastral_identifier: "68134.1609.9999.1",
      address: "гр. София, ул. Далечна №1",
      street_number: "1",
      objects_count: 1,
      geometry: factory.parse_wkt("POLYGON((24.000 43.000,24.001 43.000,24.001 43.001,24.000 43.001,24.000 43.000))")
    )
  end

  it "returns only building footprints inside the viewport" do
    result = described_class.new(bbox: "23.33,42.63,23.35,42.65").call

    expect(result.count).to eq(1)
    expect(result.geojson[:features].first.dig(:properties, :identifier)).to eq("68134.1609.4464.1")
  end

  it "finds building footprints by address independently of the viewport" do
    result = described_class.new(query: "Тестова 25").call

    expect(result.count).to eq(1)
    expect(result.geojson[:features].first.dig(:properties, :address)).to include("Тестова")
  end

  it "focuses the initial viewport on an actual covered building" do
    result = described_class.new(initial: true).call

    expect(result.geojson[:features]).to be_empty
    expect(result.center).to satisfy do |longitude, latitude|
      [
        [ [ 23.340, 23.341 ], [ 42.640, 42.641 ] ],
        [ [ 24.000, 24.001 ], [ 43.000, 43.001 ] ]
      ].any? do |longitude_range, latitude_range|
        longitude.between?(*longitude_range) && latitude.between?(*latitude_range)
      end
    end
  end
end
