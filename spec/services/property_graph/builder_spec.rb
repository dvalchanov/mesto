require "rails_helper"

RSpec.describe PropertyGraph::Builder do
  let(:analysis) { create(:property_analysis, status: "partial") }
  let(:source_url) { "https://kais.cadastre.bg/bg/OpenData" }
  let(:relevant_at) { Time.zone.parse("2026-08-05 12:00:00") }

  before do
    analysis.source_runs.create!(
      source_key: "cadastre", status: "succeeded", source_url:, relevant_at:,
      parsed_payload: { "access" => "prepared_database" }
    )
  end

  it "builds the exact property to building to parcel hierarchy" do
    create_cadastral_hierarchy

    described_class.new(analysis:).call

    edges = analysis.property_graph_relationships.includes(:subject_entity, :object_entity)
    expect(edges.map { |edge| [ edge.relationship_type, edge.subject_entity.display_name, edge.object_entity.display_name ] }).to contain_exactly(
      [ "part_of_building", analysis.individual_object_identifier, analysis.building_identifier ],
      [ "building_on_parcel", analysis.building_identifier, analysis.parcel_identifier ]
    )
    expect(edges).to all(have_attributes(status: "exact", source_key: "cadastre", active: true))
    expect(edges.map(&:evidence)).to all(include("not_ownership_evidence" => true))
  end

  it "allows a report and its source runs to be deleted after graph evidence was created" do
    create_cadastral_hierarchy
    described_class.new(analysis:).call

    expect { analysis.destroy! }.to change(PropertyAnalysis, :count).by(-1)
    expect(PropertyGraph::Relationship.where(property_analysis_id: analysis.id)).to be_empty
    expect(PropertyGraph::EntityObservation.where(property_analysis_id: analysis.id)).to be_empty
  end

  it "links an explicit NAG document and EIK without inferring ownership" do
    create_cadastral_hierarchy(ownership_type: "Частна")
    act = create(
      :administrative_act,
      registry_kind: "building_permits",
      external_key: "permit-company-1",
      source_url: "https://nag.sofia.bg/RegisterInfo/example",
      properties: {
        "organization_mentions" => [
          { "legal_name" => "ДЕВЕЛЪПМЪНТ ЕООД", "eik" => "200370069", "source_role" => "contracting_authority" }
        ]
      }
    )
    act.administrative_act_references.create!(
      cadastral_identifier: analysis.parcel_identifier,
      reference_level: "parcel",
      match_basis: "document"
    )

    described_class.new(analysis:).call

    expect(analysis.property_graph_relationships.pluck(:relationship_type)).to include(
      "related_administrative_act", "named_in_administrative_act"
    )
    expect(analysis.property_graph_relationships.where(relationship_type: %w[registered_owner previous_registered_owner])).to be_empty
    company = PropertyGraph::Entity.find_by!(canonical_key: "eik:200370069")
    expect(company.display_name).to eq("ДЕВЕЛЪПМЪНТ ЕООД")
  end

  it "links a company only from an exact AGKK right row and exposes its EIK for enrichment" do
    create_cadastral_hierarchy
    CadastreRight.create!(
      cadastral_identifier: analysis.individual_object_identifier,
      identifier_level: "individual_object",
      right_code: "1",
      right_type: "Право на собственост",
      right_description: "Ид. част 100%",
      holder_type_code: "2",
      holder_type: "Юридическо лице",
      holder_name: "ПРИМЕР ПРОЕКТ ЕООД",
      holder_identifier: "200370069",
      holder_entity_type: "company",
      document_type: "Нотариален акт",
      document_description: "№ 1 от 01.09.2026 г.",
      source_archive_key: "sofia/собственост СОС.zip",
      source_url:,
      source_relevant_at: relevant_at,
      record_fingerprint: Digest::SHA256.hexdigest("agkk-right-1")
    )

    builder = described_class.new(analysis:).call

    edge = analysis.property_graph_relationships.find_by!(relationship_type: "cadastre_right_holder")
    expect(edge).to have_attributes(
      source_key: "cadastre_ownership",
      status: "exact",
      coverage_limitation: "cadastre_rights_snapshot_not_property_register"
    )
    expect(edge.evidence).to include(
      "basis" => "exact_agkk_cadastre_right_record",
      "right_type" => "Право на собственост",
      "not_property_register_reference" => true
    )
    expect(edge.object_entity).to have_attributes(entity_type: "company", canonical_key: "eik:200370069")
    expect(builder.company_eiks).to eq([ "200370069" ])
    expect(analysis.property_graph_relationships.where(relationship_type: "registered_owner")).to be_empty
  end

  it "does not create a relationship from a NAG search hit that lacks document evidence" do
    act = create(:administrative_act, external_key: "search-only")
    act.administrative_act_references.create!(
      cadastral_identifier: analysis.parcel_identifier,
      reference_level: "parcel",
      match_basis: "search_query"
    )

    described_class.new(analysis:).call

    expect(analysis.property_graph_relationships.where(source_key: "nag_building_permits")).to be_empty
  end

  it "links a prepared planning feature only through an actual parcel intersection" do
    create_cadastral_hierarchy
    factory = RGeo::Cartesian.preferred_factory(srid: 4326)
    ring = factory.linear_ring([
      factory.point(23.32, 42.69), factory.point(23.33, 42.69),
      factory.point(23.33, 42.70), factory.point(23.32, 42.70), factory.point(23.32, 42.69)
    ])
    analysis.update!(
      parcel_geometry: factory.multi_polygon([ factory.polygon(ring) ]),
      coverage_profile_key: DataCoverage.profile.key
    )
    dataset = SpatialDataset.create!(
      key: "arcgis_development_potential", name: "Потенциал за развитие", provider: "sofiaplan_arcgis",
      source_url: "https://gis.sofiaplan.bg/layer", last_imported_at: relevant_at,
      relevant_at:, coverage_profile_key: DataCoverage.profile.key
    )
    dataset.spatial_features.create!(
      external_key: "feature-1", category: "planning_development_potential",
      name: "Зона А", geometry: factory.polygon(ring), properties: { "RegName" => "Зона А" }
    )

    described_class.new(analysis:).call

    edge = analysis.property_graph_relationships.find_by!(relationship_type: "related_development")
    expect(edge).to have_attributes(status: "supported", coverage_limitation: "planning_intersection_limited")
    expect(edge.evidence).to include("basis" => "prepared_geometry_intersection", "geometry_basis" => "parcel_polygon")
  end

  def create_cadastral_hierarchy(ownership_type: nil)
    [
      [ analysis.parcel_identifier, "parcel" ],
      [ analysis.building_identifier, "building" ],
      [ analysis.individual_object_identifier, "individual_object" ]
    ].each do |identifier, level|
      CadastralProperty.create!(
        cadastral_identifier: identifier,
        identifier_level: level,
        ownership_type:,
        source_archive_key: "sofia/#{level}.zip",
        source_url:,
        source_relevant_at: relevant_at
      )
    end
  end
end
