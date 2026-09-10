require "rails_helper"

RSpec.describe PropertyRegistry::UnavailableProvider do
  it "returns an explicit unavailable result without contacting the authenticated portal" do
    expect(DataSources::HttpClient).not_to receive(:new)

    result = described_class.new.lookup(cadastral_identifier: "68134.1000.2000")

    expect(result).to have_attributes(status: :unavailable)
    expect(result.error).to be_a(PublicRegistry::AutomationUnavailable)
  end
end
