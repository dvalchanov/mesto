require "rails_helper"

RSpec.describe CommercialRegistry::DemoProvider do
  it "returns marked company facts and current and historical relationships for the demo EIK" do
    expect(DataSources::HttpClient).not_to receive(:new)

    result = described_class.new.lookup_company(eik: "000000000")

    expect(result).to have_attributes(status: :success)
    expect(result.data).to include(demo_data: true)
    expect(result.data.fetch(:company)).to include(eik: "000000000", status: "active")
    expect(result.data.fetch(:managers).map { |manager| manager.fetch(:current) }).to contain_exactly(true, false)
    expect(result.data.fetch(:owners)).to be_present
    expect(result.data.fetch(:beneficial_owners)).to be_present
    expect(result.source_url).to start_with("https://example.invalid/")
  end

  it "does not attach synthetic company data to any other EIK" do
    result = described_class.new.lookup_company(eik: "200370069")

    expect(result).to have_attributes(status: :unavailable)
    expect(result.error).to be_a(PublicRegistry::DemoRecordUnavailable)
  end

  it "refuses to initialize in production" do
    environment = ActiveSupport::EnvironmentInquirer.new("production")

    expect { described_class.new(environment:) }.to raise_error(ArgumentError, /restricted/)
  end
end
