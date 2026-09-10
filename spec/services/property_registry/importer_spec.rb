require "rails_helper"

RSpec.describe PropertyRegistry::Importer do
  let(:analysis) { create(:property_analysis, status: "partial") }
  let(:source_url) { "https://portal.registryagency.bg/property-reference" }

  it "labels current and previous registered owners with incomplete electronic coverage" do
    described_class.new(
      analysis:,
      payload: {
        property_identifier: analysis.submitted_identifier,
        coverage: {
          complete_history: false,
          limitation: "Electronic entries available from 1992; earlier title history is outside this reference."
        },
        owners: [
          {
            legal_name: "ПРИМЕР ПРОЕКТ ЕООД", eik: "200370069", current: true,
            source_record_reference: "entry-2025-44", source_date: "2025-04-01"
          },
          {
            name: "Предишно вписано лице", current: false,
            source_record_reference: "entry-2010-12", source_date: "2010-03-03", valid_until: "2025-03-31"
          }
        ]
      },
      source_url:,
      relevant_at: Time.zone.parse("2025-04-01")
    ).call

    current = analysis.property_graph_relationships.find_by!(relationship_type: "registered_owner")
    previous = analysis.property_graph_relationships.find_by!(relationship_type: "previous_registered_owner")
    expect(current.object_entity.canonical_key).to eq("eik:200370069")
    expect(previous).not_to be_active
    expect(current.coverage_limitation).to include("Electronic entries available from 1992")
    expect(previous.coverage_limitation).to eq(current.coverage_limitation)
  end
end
