require "rails_helper"

RSpec.describe Analysis::CoverageBuilder do
  it "does not count location-dependent datasets as applicable when location is unavailable" do
    analysis = create(:property_analysis)
    analysis.source_runs.create!(source_key: "nag_design_visas", status: "succeeded")
    analysis.source_runs.create!(source_key: "cadastre", status: "unavailable")
    analysis.source_runs.create!(source_key: "arcgis_functional_zoning", status: "unavailable")
    analysis.source_runs.create!(source_key: "sofiaplan_dataset_schools", status: "unavailable")

    coverage = described_class.new(analysis.source_runs, analysis:).call

    expect(coverage).to include("succeeded" => 1, "checked" => 2)
  end
end
