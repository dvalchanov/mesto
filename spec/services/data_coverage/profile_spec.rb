require "rails_helper"

RSpec.describe DataCoverage::Profile do
  it "keeps a search boundary and a larger supporting-data boundary" do
    profile = described_class.current

    expect(profile.supporting_buffer_metres).to eq(2_000)
    expect(profile.supports_geometry_wkt?("POINT(23.275 42.665)")).to be(true)
    expect(profile.supports_geometry_wkt?("POINT(24.0 42.0)")).to be(false)
    expect(profile.scope_digest).to match(/\A[0-9a-f]{64}\z/)
  end
end
