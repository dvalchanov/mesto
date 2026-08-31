require "rails_helper"

RSpec.describe CadastralIdentifier do
  it "normalizes harmless whitespace and parses a parcel" do
    identifier = described_class.new(" 68134.1000.2000 \n")

    expect(identifier).to be_valid
    expect(identifier.to_s).to eq("68134.1000.2000")
    expect(identifier.level).to eq(:parcel)
    expect(identifier.parcel_identifier).to eq("68134.1000.2000")
    expect(identifier.building_identifier).to be_nil
  end

  it "derives building and object parents" do
    identifier = described_class.new("68134.1000.2000.1.5")

    expect(identifier.level).to eq(:individual_object)
    expect(identifier.settlement_code).to eq("68134")
    expect(identifier.cadastre_area).to eq("1000")
    expect(identifier.parcel_number).to eq("2000")
    expect(identifier.building_number).to eq("1")
    expect(identifier.object_number).to eq("5")
    expect(identifier.building_identifier).to eq("68134.1000.2000.1")
    expect(identifier.individual_object_identifier).to eq(identifier.to_s)
    expect(identifier).to be_sofia
  end

  it "accepts a non-Sofia building without calling it invalid" do
    identifier = described_class.new("12345.2.3.4")

    expect(identifier).to be_valid
    expect(identifier.level).to eq(:building)
    expect(identifier).not_to be_sofia
  end

  it "rejects malformed values" do
    [ "6813.1.2", "68134.1", "68134.1.2.3.4.5", "68134.a.2", "68134..2", "68134-1-2" ].each do |value|
      expect(described_class.new(value)).not_to be_valid
    end
  end
end
