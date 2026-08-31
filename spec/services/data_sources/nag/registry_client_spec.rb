require "rails_helper"

RSpec.describe DataSources::Nag::RegistryClient do
  let(:config) { DataSources.config.dig("nag", "registers", "building_permits") }

  it "returns a successful fixture result with provenance" do
    result = described_class.new(registry_kind: "building_permits", config:).search(identifiers: [ "68134.1000.2000" ])

    expect(result).to be_success
    expect(result.source_url).to eq(config.fetch("url"))
    expect(result.data.first.fetch("address")).to eq("ул. Тестова 1")
  end

  it "turns a network timeout into an unavailable result" do
    allow(DataSources).to receive(:fixture?).and_return(false)
    stub_request(:get, config.fetch("url")).to_timeout

    result = described_class.new(registry_kind: "building_permits", config:).search(identifiers: [ "68134.1000.2000" ])

    expect(result).to be_unavailable
    expect(result.error).to be_a(Faraday::ConnectionFailed).or be_a(Faraday::TimeoutError)
  end
end
