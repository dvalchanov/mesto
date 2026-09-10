require "rails_helper"

RSpec.describe Analysis::Starter do
  let(:identifier) { CadastralIdentifier.new("68134.1000.2000.1.5") }

  it "reuses an old completed analysis while its prepared-data revisions are current" do
    analysis = create(:property_analysis, status: "ready", completed_at: 2.months.ago)
    revisions = Analysis::PreparedDataRevisionSet.call(
      profile: DataCoverage.profile,
      identifiers: analysis.identifiers_for_matching
    )
    analysis.analysis_revisions.create!(
      number: 1,
      coverage_profile_key: DataCoverage.profile.key,
      calculation_version: Analysis::Runner::CALCULATION_VERSION,
      status: "ready",
      dataset_revisions: revisions,
      completed_at: 2.months.ago
    )

    expect { @result = described_class.new(identifier).call }.not_to change(PropertyAnalysis, :count)
    expect(@result).to eq(analysis)
    expect(AnalyzePropertyJob).not_to have_been_enqueued
  end

  it "starts a new analysis when the prepared-data revisions changed" do
    analysis = create(:property_analysis, status: "ready", completed_at: 1.hour.ago)
    analysis.analysis_revisions.create!(
      number: 1,
      coverage_profile_key: DataCoverage.profile.key,
      status: "ready",
      dataset_revisions: { "source:example" => "outdated" },
      completed_at: 1.hour.ago
    )

    expect { @result = described_class.new(identifier).call }.to change(PropertyAnalysis, :count).by(1)
    expect(@result).not_to eq(analysis)
    expect(AnalyzePropertyJob).to have_been_enqueued.with(@result.id)
  end

  it "does not invalidate a report when another property gets a newer bounded NAG snapshot" do
    profile = DataCoverage.profile
    SourceSnapshot.create!(
      source_key: "nag_building_permits", provider: "NAG",
      source_url: "https://nag.sofia.bg/building-permits", coverage_profile_key: profile.key,
      status: "succeeded", coverage_status: "complete", fetched_at: 1.hour.ago,
      permission_status: "approved", revision: "matching",
      metadata: {
        "searched_identifiers" => [ identifier.to_s, identifier.building_identifier, identifier.parcel_identifier ].compact.uniq
      }
    )
    analysis = create(:property_analysis, status: "ready", completed_at: 1.hour.ago)
    analysis.analysis_revisions.create!(
      number: 1,
      coverage_profile_key: profile.key,
      calculation_version: Analysis::Runner::CALCULATION_VERSION,
      status: "ready",
      dataset_revisions: Analysis::PreparedDataRevisionSet.call(
        profile:,
        identifiers: analysis.identifiers_for_matching
      ),
      completed_at: 1.hour.ago
    )
    SourceSnapshot.create!(
      source_key: "nag_building_permits", provider: "NAG",
      source_url: "https://nag.sofia.bg/building-permits", coverage_profile_key: profile.key,
      status: "succeeded", coverage_status: "complete", fetched_at: Time.current,
      permission_status: "approved", revision: "different-property",
      metadata: { "searched_identifiers" => [ "68134.9999.9999" ] }
    )

    expect { @result = described_class.new(identifier).call }.not_to change(PropertyAnalysis, :count)
    expect(@result).to eq(analysis)
  end
end
