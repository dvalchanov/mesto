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
end
