require "rails_helper"

RSpec.describe Cadastre::OpenDataProvider do
  it "returns the exact imported cadastral property facts with provenance" do
    property = CadastralProperty.create!(
      cadastral_identifier: "68134.1609.3263.1.10", identifier_level: "individual_object",
      area_sqm: 136.01, object_number: "А-10", floor: "2", levels_count: 1,
      purpose: "Жилище, апартамент", address: "гр. София, ет. 2, ап. А-10",
      source_archive_key: "district/objects.zip", source_url: "https://kais.cadastre.bg/source",
      source_relevant_at: Time.zone.parse("2026-08-05")
    )

    result = described_class.new(config: {
      "portal_url" => "https://kais.cadastre.bg/bg/OpenData", "auto_import" => false
    }, coverage_profile: accepting(everything: true)).locate(identifier: property.cadastral_identifier)

    expect(result).to be_success
    expect(result.data).to include(
      "subject_area_sqm" => 136.01, "object_number" => "А-10",
      "floor" => "2", "levels_count" => 1
    )
    expect(result.relevant_at).to eq(property.source_relevant_at)
  end

  it "returns the complete exact hierarchy and official parcel geometry" do
    source = {
      source_archive_key: "district/data.zip", source_url: "https://kais.cadastre.bg/source",
      source_relevant_at: Time.zone.parse("2026-08-05")
    }
    parcel = CadastralProperty.create!(
      **source, cadastral_identifier: "68134.1609.3263", identifier_level: "parcel",
      area_sqm: 2500.38, regulation_parcel: "IX-3263", permanent_use: "Средно застрояване"
    )
    CadastralProperty.create!(
      **source, cadastral_identifier: "68134.1609.3263.1", identifier_level: "building",
      area_sqm: 841.84, floors_count: 4, objects_count: 52
    )
    object = CadastralProperty.create!(
      **source, cadastral_identifier: "68134.1609.3263.1.10", identifier_level: "individual_object",
      area_sqm: 136.01, object_number: "А-10"
    )
    CadastralProperty.where(id: parcel.id).update_all(<<~SQL.squish)
      geometry = ST_Multi(ST_GeomFromText('POLYGON((23 42,23.01 42,23.01 42.01,23 42.01,23 42))', 4326))
    SQL

    result = described_class.new(config: {
      "portal_url" => "https://kais.cadastre.bg/bg/OpenData", "auto_import" => false
    }, coverage_profile: accepting(everything: true)).locate(identifier: object.cadastral_identifier)

    expect(result.data.fetch("cadastre_records").keys).to contain_exactly(
      "parcel", "building", "individual_object"
    )
    expect(result.data.fetch("cadastre_records").dig("building", "objects_count")).to eq(52)
    expect(result.data.fetch("cadastre_records").dig("parcel", "regulation_parcel")).to eq("IX-3263")
    expect(result.data.fetch("geometry").geometry_type.type_name).to eq("MultiPolygon")
    expect(result.data.fetch("centroid").x).to be_within(0.001).of(23.005)
    expect(result.data.fetch("centroid").y).to be_within(0.001).of(42.005)
  end

  it "distinguishes an imported property outside search coverage from missing prepared data" do
    factory = RGeo::Cartesian.preferred_factory(srid: 4326)
    ring = factory.linear_ring([
      factory.point(24.0, 42.0), factory.point(24.01, 42.0),
      factory.point(24.01, 42.01), factory.point(24.0, 42.01),
      factory.point(24.0, 42.0)
    ])
    source = {
      source_archive_key: "district/data.zip",
      source_url: "https://kais.cadastre.bg/source"
    }
    property = CadastralProperty.create!(
      **source,
      cadastral_identifier: "68134.1000.9999",
      identifier_level: "parcel",
      geometry: factory.polygon(ring)
    )
    provider = described_class.new(
      config: { "portal_url" => "https://kais.cadastre.bg/bg/OpenData" },
      coverage_profile: accepting(everything: false)
    )

    outside = provider.locate(identifier: property.cadastral_identifier)
    missing = provider.locate(identifier: "68134.1000.8888")

    expect(outside.error).to be_a(DataCoverage::OutsideSearchCoverage)
    expect(missing.error).to be_a(DataCoverage::DatasetNotPrepared)
  end


  def accepting(everything:)
    instance_double(
      DataCoverage::Profile,
      covers_property?: everything,
      label: "test coverage"
    )
  end
end
