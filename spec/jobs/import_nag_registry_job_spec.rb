require "rails_helper"

RSpec.describe ImportNagRegistryJob do
  it "persists a reusable, identifier-scoped successful snapshot" do
    identifiers = %w[68134.1000.2000.1.5 68134.1000.2000.1 68134.1000.2000]

    expect {
      described_class.perform_now(
        "design_visas",
        identifiers,
        coverage_profile_key: DataCoverage.profile.key
      )
    }.to change(SourceSnapshot, :count).by(1)

    snapshot = SourceSnapshot.last
    expect(snapshot).to have_attributes(
      source_key: "nag_design_visas",
      status: "succeeded",
      coverage_status: "complete",
      record_count: 1
    )
    expect(snapshot.metadata.fetch("searched_identifiers")).to eq(identifiers.sort)
    expect(
      SourceSnapshot.latest_for_identifiers(
        "nag_design_visas", identifiers:, profile: DataCoverage.profile
      )
    ).to eq(snapshot)
  end
end
