require "rails_helper"

RSpec.describe Cadastre::HierarchyMetricsBuilder do
  it "cross-checks exact child records and labels derived area metrics" do
    analysis = create(
      :property_analysis, submitted_identifier: "68134.1609.3263.1.10",
      parcel_identifier: "68134.1609.3263", building_identifier: "68134.1609.3263.1",
      individual_object_identifier: "68134.1609.3263.1.10"
    )
    source = { source_url: "https://kais.cadastre.bg/source", source_relevant_at: Time.zone.parse("2026-08-05") }
    parcel = CadastralProperty.create!(
      **source, cadastral_identifier: analysis.parcel_identifier, identifier_level: "parcel",
      area_sqm: 2500.38, source_archive_key: "district/parcels.zip"
    )
    building = CadastralProperty.create!(
      **source, cadastral_identifier: analysis.building_identifier, identifier_level: "building",
      area_sqm: 841.84, objects_count: 2, source_archive_key: "district/buildings.zip"
    )
    object = CadastralProperty.create!(
      **source, cadastral_identifier: analysis.individual_object_identifier,
      identifier_level: "individual_object", area_sqm: 86.01,
      source_archive_key: "district/objects.zip"
    )
    CadastralProperty.create!(
      **source, cadastral_identifier: "68134.1609.3263.1.11",
      identifier_level: "individual_object", area_sqm: 50,
      source_archive_key: "district/objects.zip"
    )
    %w[district/buildings.zip district/objects.zip].each_with_index do |archive_key, index|
      CadastreImport.create!(
        source_archive_key: archive_key, source_url: source.fetch(:source_url), status: "succeeded",
        checksum: "checksum-#{index}", importer_version: 2
      )
    end

    metrics = described_class.new(
      analysis:, properties: { "parcel" => parcel, "building" => building, "individual_object" => object }
    ).call

    expect(metrics).to include(
      "parcel_buildings_count" => 1,
      "parcel_building_footprint_sqm" => 841.84,
      "parcel_footprint_percent" => 33.67,
      "building_object_records_count" => 2,
      "building_declared_objects_count" => 2,
      "building_object_count_matches" => true,
      "building_object_areas_sum_sqm" => 136.01
    )
  end
end
