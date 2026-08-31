require "rails_helper"

RSpec.describe DataSources::Nag::DetailParser do
  it "extracts safe detail fields and multiple identifiers" do
    details = described_class.new.parse(DataSources::FixtureLoader.read("nag_detail.html"))

    expect(details.fetch("upi")).to eq("I-2000")
    expect(details.fetch("cadastral_identifiers")).to contain_exactly("68134.1000.2000", "68134.1000.2000.1.5")
  end
end
