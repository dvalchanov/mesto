require "rails_helper"

RSpec.describe Analysis::DueDiligenceBuilder do
  it "combines report results with external, document and professional checks" do
    analysis = create(
      :property_analysis,
      status: "ready",
      summary: { "planning_summary" => { "available" => true } },
      metrics: {
        "environment" => { "available" => true, "flood_risk_intersections" => 0 },
        "amenities" => { "availability" => { "schools" => true } }
      }
    )
    analysis.source_runs.create!(source_key: "cadastre", status: "succeeded", source_url: "https://example.test/cadastre")
    analysis.source_runs.create!(source_key: "nag_design_visas", status: "succeeded", source_url: "https://example.test/visas")
    analysis.source_runs.create!(source_key: "nag_building_permits", status: "succeeded", source_url: "https://example.test/permits")
    permit = create(:administrative_act, registry_kind: "building_permits")
    permit.administrative_act_references.create!(
      cadastral_identifier: analysis.parcel_identifier,
      reference_level: "parcel"
    )

    sections = described_class.new(
      analysis:,
      facts: { "subject_area_sqm" => 82.4, "address" => "Sofia", "cadastre_records" => {} }
    ).call
    topics = sections.flat_map { |section| section.fetch("items") }.index_by { |item| item.fetch("key") }

    expect(sections.map { |section| section.fetch("key") }).to eq(
      %w[identity planning_construction legal_seller building_condition location_context transaction]
    )
    expect(topics.size).to eq(30)
    expect(topics.fetch("cadastre_identity")).to include("result" => "verified_in_report")
    expect(topics.fetch("area_comparison")).to include("result" => "partial_in_report")
    expect(topics.fetch("design_visa")).to include("result" => "checked_no_match")
    expect(topics.fetch("building_permit")).to include("result" => "found_in_report", "count" => 1)
    expect(topics.fetch("title_chain")).to include("result" => "external_official_check")
    expect(topics.fetch("technical_inspection")).to include("result" => "professional_review")
    expect(topics.fetch("flood_risk")).to include("result" => "flood_assessed", "count" => 0)
    expect(topics.fetch("area_comparison").fetch("sources")).to include(
      "key" => "cadastre_object_scheme",
      "url" => Analysis::DueDiligenceBuilder::SOURCE_URLS.fetch("cadastre_object_scheme")
    )
    expect(topics.fetch("area_comparison").fetch("sources")).to include(
      "key" => "cadastre",
      "url" => Analysis::DueDiligenceBuilder::SOURCE_URLS.fetch("cadastre")
    )
    expect(topics.fetch("area_comparison").fetch("sources")).not_to include(
      "key" => "cadastre", "url" => "https://example.test/cadastre"
    )
    expect(topics.fetch("design_visa").fetch("sources")).to include(
      "key" => "nag_design_visas",
      "url" => "https://example.test/visas"
    )
    expect(topics.fetch("building_permit").fetch("sources")).to include(
      "key" => "nag_building_permits",
      "url" => "https://example.test/permits"
    )
    expect(topics.fetch("encumbrances").fetch("sources")).to include(
      "key" => "property_registry_certificate_help",
      "url" => Analysis::DueDiligenceBuilder::SOURCE_URLS.fetch("property_registry_certificate_help")
    )
  end

  it "marks attempted but failed report sources as unavailable without implying absence" do
    analysis = create(:property_analysis, status: "partial")
    analysis.source_runs.create!(source_key: "cadastre", status: "unavailable")
    analysis.source_runs.create!(source_key: "nag_occupancy_certificates", status: "failed")

    sections = described_class.new(analysis:, facts: {}).call
    topics = sections.flat_map { |section| section.fetch("items") }.index_by { |item| item.fetch("key") }

    expect(topics.fetch("cadastre_identity")).to include("result" => "source_unavailable")
    expect(topics.fetch("occupancy")).to include("result" => "source_unavailable")
    expect(topics.fetch("area_comparison")).to include("result" => "request_document")
  end

  it "links area checks to the official document for the identifier level" do
    expected_source_keys = {
      "parcel" => "cadastre_parcel_sketch",
      "building" => "cadastre_building_sketch",
      "individual_object" => "cadastre_object_scheme"
    }

    expected_source_keys.each do |identifier_level, source_key|
      analysis = create(:property_analysis, identifier_level:)
      sections = described_class.new(analysis:, facts: {}).call
      area_topic = sections.flat_map { |section| section.fetch("items") }.find do |topic|
        topic.fetch("key") == "area_comparison"
      end

      expect(area_topic.fetch("sources")).to include(
        "key" => source_key,
        "url" => Analysis::DueDiligenceBuilder::SOURCE_URLS.fetch(source_key)
      )
    end
  end
end
