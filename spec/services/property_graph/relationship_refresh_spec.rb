require "rails_helper"

RSpec.describe PropertyGraph::RelationshipRefresh do
  it "preserves conflicting source claims without resolving them by guesswork" do
    analysis = create(:property_analysis)
    observed_at = Time.zone.parse("2026-09-01")
    subject = PropertyGraph::EntityResolver.call(
      entity_type: "parcel", canonical_key: "cadastre:#{analysis.parcel_identifier}",
      display_name: analysis.parcel_identifier, identifiers: { "cadastral_identifier" => analysis.parcel_identifier },
      observed_at:
    )
    owners = %w[200370069 131071587].map do |eik|
      PropertyGraph::EntityResolver.call(
        entity_type: "company", canonical_key: "eik:#{eik}", display_name: "Дружество #{eik}",
        identifiers: { "eik" => eik }, observed_at:
      )
    end
    claims = owners.map.with_index do |owner, index|
      {
        subject_entity: subject,
        object_entity: owner,
        relationship_type: "registered_owner",
        status: "conflicting",
        source_url: "https://example.test/source/#{index}",
        source_record_reference: "conflict-#{index}",
        subject_scope: { "cadastral_identifier" => analysis.parcel_identifier },
        object_scope: { "eik" => owner.identifiers.fetch("eik") },
        evidence: { "basis" => "conflicting_test_records" },
        coverage_limitation: "The supplied records conflict and require manual resolution."
      }
    end

    described_class.new(
      analysis:, source_key: "property_register", refresh_scope: "conflict-test", observed_at:
    ).call(claims)

    expect(analysis.property_graph_relationships.pluck(:status)).to contain_exactly("conflicting", "conflicting")
    expect(PropertyGraph::Presenter.new(analysis:).call.fetch("edges").length).to eq(2)
  end
end
