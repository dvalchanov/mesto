require "rails_helper"

RSpec.describe PropertyFinder::AddressSearch do
  let(:source) do
    {
      identifier_level: "individual_object",
      source_archive_key: "test/individual-objects.zip",
      source_url: "https://kais.cadastre.bg/bg/OpenData"
    }
  end

  before do
    CadastralProperty.create!(
      **source,
      cadastral_identifier: "68134.1609.4464.1.16",
      address: 'гр. София, район Студентски, ж.к. "Малинова долина", ул. "Проф. Крикор Азарян" №25, вх. А, ет. 2, ап. А16',
      street_number: "25",
      entrance: "А", floor: "2", object_number: "А16", area_sqm: 75.2,
      purpose: "Жилище, апартамент", purpose_code: "500"
    )
    CadastralProperty.create!(
      **source,
      cadastral_identifier: "68134.1609.4464.1.17",
      address: 'гр. София, район Студентски, ж.к. "Малинова долина", вх. А, ет. 3, ап. А17',
      entrance: "А", floor: "3", object_number: "А17", area_sqm: 82.4,
      purpose: "Жилище, апартамент", purpose_code: "500"
    )
    CadastralProperty.create!(
      **source,
      cadastral_identifier: "68134.1609.9999.1.1",
      address: "гр. София, ул. Друга №25, ет. 2, ап. 1",
      street_number: "25",
      floor: "2", object_number: "1", area_sqm: 82.0
    )
    CadastralProperty.create!(
      **source,
      cadastral_identifier: "68134.1609.4464.1.18",
      address: 'гр. София, ул. "Проф. Крикор Азарян" №25, ет. -1, гараж 1',
      street_number: "25", floor: "-1", object_number: "1", area_sqm: 18,
      purpose: "Гараж", purpose_code: "530"
    )
  end

  it "finds the building by address and returns every unit in that building" do
    result = described_class.new(query: "ул. Проф. Крикор Азарян 25").call

    expect(result.building_count).to eq(1)
    expect(result.total_count).to eq(2)
    expect(result.properties.map(&:cadastral_identifier)).to contain_exactly(
      "68134.1609.4464.1.16",
      "68134.1609.4464.1.17"
    )
    expect(result.properties.map(&:purpose)).not_to include("Гараж")
    expect(result.building_addresses.fetch("68134.1609.4464.1")).to end_with("№25")
    expect(result.entrances).to eq([ "А" ])
    expect(result.floors).to eq([ "2", "3" ])
  end

  it "narrows candidates with whichever details the visitor knows" do
    result = described_class.new(
      query: "Крикор Азарян 25",
      filters: { floor: "3", area: "80", object_number: "17" }
    ).call

    expect(result.total_count).to eq(1)
    expect(result.properties.first.cadastral_identifier).to eq("68134.1609.4464.1.17")
  end

  it "does not turn a generic location stop word into an unbounded search" do
    result = described_class.new(query: "София").call

    expect(result.building_count).to eq(0)
    expect(result.total_count).to eq(0)
  end
end
