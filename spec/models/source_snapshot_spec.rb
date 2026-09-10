require "rails_helper"

RSpec.describe SourceSnapshot do
  it "selects only a snapshot that searched every requested cadastral identifier" do
    profile = DataCoverage.profile
    attributes = {
      source_key: "nag_design_visas",
      provider: "NAG",
      source_url: "https://nag.sofia.bg/registervisasofproection",
      coverage_profile_key: profile.key,
      status: "succeeded",
      coverage_status: "complete",
      permission_status: "approved",
      fetched_at: Time.current
    }
    described_class.create!(
      **attributes,
      metadata: { "searched_identifiers" => %w[68134.1.1] }
    )
    matching = described_class.create!(
      **attributes,
      metadata: { "searched_identifiers" => %w[68134.1.1 68134.1.1.1] }
    )

    result = described_class.latest_for_identifiers(
      "nag_design_visas",
      identifiers: %w[68134.1.1.1 68134.1.1],
      profile:
    )

    expect(result).to eq(matching)
  end
end
