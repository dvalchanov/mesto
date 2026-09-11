require "rails_helper"

RSpec.describe PropertyFinder::BuildingSearch do
  let(:factory) { RGeo::Cartesian.preferred_factory(srid: 4326) }
  let(:geometry) { factory.parse_wkt("POLYGON((23.340 42.640,23.341 42.640,23.341 42.641,23.340 42.641,23.340 42.640))") }
  let(:source) do
    {
      identifier_level: "building",
      source_archive_key: "test/buildings.zip",
      source_url: "https://kais.cadastre.bg/bg/OpenData",
      geometry:
    }
  end

  before do
    CadastralProperty.create!(
      **source,
      cadastral_identifier: "68134.1609.4464.1",
      address: 'гр. София, ж.к. "Малинова долина"'
    )
    CadastralProperty.create!(
      **source.except(:identifier_level, :geometry),
      identifier_level: "individual_object",
      cadastral_identifier: "68134.1609.4464.1.16",
      address: 'гр. София, ж.к. "Малинова долина", ул. "Проф. Крикор Азарян" №25, вх. А, ет. 2, ап. 16',
      street_name: 'ул. "Проф. Крикор Азарян"',
      street_number: "25"
    )
    CadastralProperty.create!(
      **source,
      cadastral_identifier: "68134.1609.4464.2",
      address: 'гр. София, ж.к. "Малинова долина", ул. "Проф. Крикор Азарян" №25',
      street_name: 'ул. "Проф. Крикор Азарян"',
      street_number: "25"
    )
    CadastralProperty.create!(
      **source,
      cadastral_identifier: "68134.1609.4465.1",
      address: 'гр. София, ул. "Проф. Крикор Азарян" №27',
      street_number: "27"
    )
  end

  it "groups matching buildings under the address shown to the visitor" do
    suggestions = described_class.new(query: "Крикор Азарян 25").call

    expect(suggestions.length).to eq(1)
    expect(suggestions.first.building_count).to eq(2)
    expect(suggestions.first.building_identifier).to be_nil
  end

  it "returns an exact identifier when one building has the address" do
    suggestion = described_class.new(query: "Крикор Азарян 27").call.first

    expect(suggestion.building_count).to eq(1)
    expect(suggestion.building_identifier).to eq("68134.1609.4465.1")
  end
end
