require "rails_helper"

RSpec.describe Vies::Importer do
  it "adds a dated VAT observation to the exact company without creating a property relationship" do
    analysis = create(:property_analysis)
    company = PropertyGraph::EntityResolver.call(
      entity_type: "company",
      canonical_key: "eik:205479841",
      display_name: "НЕКСТ БИЛД ИНВЕСТ ЕООД",
      identifiers: { "eik" => "205479841" }
    )
    source_run = analysis.source_runs.create!(
      source_key: "vies",
      status: "succeeded",
      source_url: "https://ec.europa.eu/taxation_customs/vies/services/checkVatService"
    )

    result = described_class.new(
      analysis:,
      payload: {
        eik: "205479841", vat_valid: true, request_date: "2026-09-10",
        legal_name: "НЕКСТ БИЛД ИНВЕСТ ЕООД"
      },
      source_url: source_run.source_url,
      source_run:,
      relevant_at: Time.zone.parse("2026-09-10")
    ).call

    expect(result).to eq(company)
    observation = company.observations.find_by!(property_analysis: analysis, source_key: "vies")
    expect(observation.facts).to include(
      "vat_number" => "BG205479841",
      "vat_registered" => true,
      "vat_checked_on" => "2026-09-10"
    )
    expect(observation.coverage_limitation).to eq("vies_vat_status_only")
    expect(analysis.property_graph_relationships).to be_empty
  end
end
