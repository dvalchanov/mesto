require "rails_helper"

RSpec.describe PropertyRegistry::DemoProvider do
  it "returns the complete marked synthetic ownership payload only for the demo identifier" do
    expect(DataSources::HttpClient).not_to receive(:new)

    result = described_class.new.lookup(cadastral_identifier: "68134.1607.1254.1.5")

    expect(result).to have_attributes(status: :success)
    expect(result.data).to include(demo_data: true, property_identifier: "68134.1607.1254.1.5")
    expect(result.data.fetch(:owners).map { |owner| owner.fetch(:current) }).to contain_exactly(true, false)
    expect(result.source_url).to start_with("https://example.invalid/")
  end

  it "does not attach synthetic ownership to any other identifier" do
    result = described_class.new.lookup(cadastral_identifier: "68134.1607.1254.1.6")

    expect(result).to have_attributes(status: :unavailable)
    expect(result.error).to be_a(PublicRegistry::DemoRecordUnavailable)
  end

  it "refuses to initialize in production" do
    environment = ActiveSupport::EnvironmentInquirer.new("production")

    expect { described_class.new(environment:) }.to raise_error(ArgumentError, /restricted/)
  end
end
