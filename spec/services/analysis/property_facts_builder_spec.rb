require "rails_helper"

RSpec.describe Analysis::PropertyFactsBuilder do
  it "exposes identifier facts and property-specific cadastre attributes" do
    analysis = create(
      :property_analysis, status: "partial", submitted_identifier: "68134.9988.7777.1.2",
      parcel_identifier: "68134.9988.7777", building_identifier: "68134.9988.7777.1",
      individual_object_identifier: "68134.9988.7777.1.2"
    )
    analysis.source_runs.create!(
      source_key: "cadastre", status: "succeeded", parsed_payload: {
        "object_area_sqm" => "72.45", "address" => "ул. Тестова 1"
      }
    )

    facts = described_class.new(analysis:).call

    expect(facts).to include(
      "property_type" => "individual_object",
      "cadastre_area_code" => "9988",
      "parcel_number" => "7777",
      "subject_area_sqm" => 72.45,
      "subject_area_source" => "cadastre",
      "address" => "ул. Тестова 1"
    )
  end

  it "uses linked municipal records for clearly labelled location facts without inventing area" do
    analysis = create(
      :property_analysis, status: "partial", submitted_identifier: "68134.9987.7776.1.2",
      parcel_identifier: "68134.9987.7776", building_identifier: "68134.9987.7776.1",
      individual_object_identifier: "68134.9987.7776.1.2"
    )
    act = create(
      :administrative_act, district: "Студентски", locality: nil, upi: nil,
      object_description: 'Местност "Малинова долина", УПИ IX-2000, квартал 51'
    )
    act.administrative_act_references.create!(
      cadastral_identifier: analysis.parcel_identifier, reference_level: "parcel"
    )

    facts = described_class.new(analysis:).call

    expect(facts).to include(
      "subject_area_sqm" => nil,
      "district" => "Студентски",
      "locality" => "Малинова долина",
      "upi" => "IX-2000",
      "direct_acts_count" => 1
    )
  end

  it "fills an older report from the exact imported AGKK object record" do
    analysis = create(
      :property_analysis, status: "partial", submitted_identifier: "68134.1609.3263.1.10",
      parcel_identifier: "68134.1609.3263", building_identifier: "68134.1609.3263.1",
      individual_object_identifier: "68134.1609.3263.1.10"
    )
    analysis.source_runs.create!(source_key: "cadastre", status: "unavailable")
    relevant_at = Time.zone.parse("2026-08-05")
    CadastralProperty.create!(
      cadastral_identifier: analysis.submitted_identifier, identifier_level: "individual_object",
      area_sqm: 136.01, object_number: "А-10", floor: "2", levels_count: 1,
      address: "гр. София, район Студентски, ет. 2, ап. А-10",
      source_archive_key: "district/objects.zip", source_url: "https://kais.cadastre.bg/source",
      source_relevant_at: relevant_at
    )
    CadastralProperty.create!(
      cadastral_identifier: analysis.parcel_identifier, identifier_level: "parcel",
      area_sqm: 2500.38, source_archive_key: "district/parcels.zip",
      source_url: "https://kais.cadastre.bg/source", source_relevant_at: relevant_at
    )

    facts = described_class.new(analysis:).call

    expect(facts).to include(
      "subject_area_sqm" => 136.01,
      "subject_area_source" => "cadastre",
      "address_source" => "cadastre",
      "object_number" => "А-10",
      "floor" => "2",
      "levels_count" => 1,
      "parcel_area_sqm" => 2500.38,
      "parcel_area_source" => "cadastre",
      "cadastre_relevant_at" => relevant_at
    )
  end
end
