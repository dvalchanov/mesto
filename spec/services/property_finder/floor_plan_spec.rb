require "rails_helper"

RSpec.describe PropertyFinder::FloorPlan do
  let(:factory) { RGeo::Cartesian.preferred_factory(srid: 4326) }
  let(:source) do
    {
      source_archive_key: "test/cadastre.zip",
      source_url: "https://kais.cadastre.bg/bg/OpenData"
    }
  end

  it "combines the selected building with only the supplied candidate units" do
    building = CadastralProperty.create!(
      **source,
      identifier_level: "building",
      cadastral_identifier: "68134.1609.4464.1",
      address: "гр. София, ул. Тестова №25",
      geometry: factory.parse_wkt("POLYGON((23.340 42.640,23.342 42.640,23.342 42.642,23.340 42.642,23.340 42.640))")
    )
    unit = CadastralProperty.create!(
      **source,
      identifier_level: "individual_object",
      cadastral_identifier: "68134.1609.4464.1.16",
      address: "гр. София, ул. Тестова №25, ет. 2, ап. 16",
      floor: "2",
      object_number: "16",
      geometry: factory.parse_wkt("POLYGON((23.340 42.640,23.341 42.640,23.341 42.641,23.340 42.641,23.340 42.640))")
    )

    payload = described_class.new(building_identifier: building.cadastral_identifier, properties: [ unit ]).call

    expect(payload[:features].map { |feature| feature.dig(:properties, :kind) }).to contain_exactly("building", "unit")
    expect(payload[:features].last.dig(:properties, :object_number)).to eq("16")
  end
end
