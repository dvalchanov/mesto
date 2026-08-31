require "rails_helper"

RSpec.describe DataSources::Nag::RegistryParser do
  subject(:parser) do
    described_class.new(registry_kind: "building_permits", base_url: "https://nag.sofia.bg/RegisterBuildingPermitsPortal/Index")
  end

  it "parses records and multiple cadastral identifiers without personal applicants" do
    records = parser.parse(DataSources::FixtureLoader.read("nag_building_permits_search.html"))

    expect(records.one?).to be(true)
    expect(records.first.fetch("act_number")).to eq("РС-101")
    expect(records.first.fetch("cadastral_identifiers")).to contain_exactly("68134.1000.2000", "68134.1000.2000.1.5")
    expect(records.first.fetch("properties")).not_to have_key("Employer")
  end

  it "parses the embedded Kendo JSON contract used by the live register" do
    data = { Data: [ { Id: 7, Hash: "hash-7", Number: "7", FileTypeName: "Виза", DateFilter: "/Date(1646344800000)/", Identifier: "68134.1000.2000" } ], Total: 1 }
    html = "<script>widget({\"data\":#{data.to_json}});</script>"

    expect(parser.parse(html).first).to include("external_key" => "hash-7", "act_number" => "7", "title" => "Виза", "issued_on" => Date.new(2022, 3, 3))
  end

  it "returns an empty collection for empty or changed HTML" do
    expect(parser.parse(DataSources::FixtureLoader.read("nag_empty.html"))).to be_empty
    expect(parser.parse(DataSources::FixtureLoader.read("nag_malformed.html"))).to be_empty
  end
end
