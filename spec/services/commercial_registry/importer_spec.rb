require "rails_helper"

RSpec.describe CommercialRegistry::Importer do
  let(:analysis) { create(:property_analysis, status: "partial") }
  let(:source_url) { "https://portal.registryagency.bg/CR/company" }
  let(:first_observation) { Time.zone.parse("2026-08-01 10:00:00") }

  it "normalizes company managers, owners, material status, and historical changes" do
    described_class.new(
      analysis:,
      payload: company_payload(
        managers: [
          { name: "Текущ управител", current: true, valid_from: "2024-01-01" },
          { name: "Предишен управител", current: false, valid_from: "2020-01-01", valid_until: "2023-12-31" }
        ],
        owners: [
          { legal_name: "ХОЛДИНГ АД", eik: "131071587", current: true, ownership_percentage: "100" }
        ]
      ),
      source_url:,
      observed_at: first_observation,
      relevant_at: first_observation
    ).call

    company = PropertyGraph::Entity.find_by!(canonical_key: "eik:200370069")
    observation = company.observations.find_by!(property_analysis: analysis, source_key: "commercial_register")
    expect(observation.facts).to include(
      "status" => "active",
      "registration_date" => "2018-02-01",
      "liquidation_status" => "none",
      "insolvency_status" => "none"
    )
    expect(observation.facts.fetch("material_circumstances")).to contain_exactly(
      include("type" => "capital_change", "date" => "2025-06-01")
    )
    expect(company.outgoing_relationships.where(property_analysis: analysis).pluck(:relationship_type)).to contain_exactly(
      "managed_by", "managed_by", "owned_by"
    )
    expect(company.outgoing_relationships.historical.sole.valid_until).to eq(Date.new(2023, 12, 31))
  end

  it "keeps similar company names distinct by exact EIK" do
    described_class.new(analysis:, payload: company_payload, source_url:).call
    described_class.new(
      analysis:,
      payload: company_payload(eik: "131071587", legal_name: "ПРИМЕР ПРОЕКТ ЕООД"),
      source_url:
    ).call

    expect(PropertyGraph::Entity.companies.where(display_name: "ПРИМЕР ПРОЕКТ ЕООД").pluck(:canonical_key)).to contain_exactly(
      "eik:200370069", "eik:131071587"
    )
  end

  it "closes changed current relationships without destroying their observed history" do
    described_class.new(
      analysis:,
      payload: company_payload(managers: [ { name: "Стар управител", current: true } ]),
      source_url:,
      observed_at: first_observation
    ).call
    second_observation = first_observation + 2.days
    described_class.new(
      analysis:,
      payload: company_payload(managers: [ { name: "Нов управител", current: true } ]),
      source_url:,
      observed_at: second_observation
    ).call

    relationships = PropertyGraph::Relationship.where(property_analysis: analysis, relationship_type: "managed_by")
    expect(relationships.count).to eq(2)
    old_relationship = relationships.joins(:object_entity).find_by!(property_graph_entities: { display_name: "Стар управител" })
    expect(old_relationship).to have_attributes(
      active: false,
      first_observed_at: first_observation,
      last_observed_at: first_observation,
      superseded_at: second_observation
    )
    expect(relationships.current.sole.object_entity.display_name).to eq("Нов управител")
  end

  it "reuses one exact-EIK entity across public sources" do
    existing = PropertyGraph::EntityResolver.call(
      entity_type: "company", canonical_key: "eik:200370069", display_name: "ПРИМЕР ПРОЕКТ",
      identifiers: { "eik" => "200370069" }, observed_at: first_observation - 1.day
    )
    PropertyGraph::ObservationWriter.call(
      entity: existing, analysis:, source_key: "nag_building_permits", source_url: "https://nag.sofia.bg/record",
      source_record_reference: "permit-1", observed_at: first_observation - 1.day
    )

    imported = described_class.new(analysis:, payload: company_payload, source_url:).call

    expect(imported).to eq(existing)
    expect(imported.observations.where(property_analysis: analysis).pluck(:source_key)).to contain_exactly(
      "nag_building_permits", "commercial_register"
    )
  end

  def company_payload(eik: "200370069", legal_name: "ПРИМЕР ПРОЕКТ ЕООД", managers: [], owners: [])
    {
      company: {
        eik:,
        legal_name:,
        status: "active",
        registration_date: "2018-02-01",
        liquidation_status: "none",
        insolvency_status: "none",
        source_record_reference: "company/#{eik}",
        material_circumstances: [ { type: "capital_change", date: "2025-06-01", description: "Registered capital change" } ]
      },
      managers:,
      owners:
    }
  end
end
