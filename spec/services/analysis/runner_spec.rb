require "rails_helper"

RSpec.describe Analysis::Runner do
  it "completes a useful partial report while preserving independent source states" do
    DataSources::Sofiaplan::DatasetSynchronizer.new.sync
    analysis = create(:property_analysis)

    described_class.new(analysis).call

    expect(analysis.reload.status).to eq("partial")
    expect(analysis.location_precision).to eq("official_record_geometry")
    expect(analysis.source_runs.succeeded.count).to be >= 1
    expect(analysis.source_runs.where(status: "unavailable", source_key: "cadastre")).to exist
    expect(analysis.administrative_acts.count).to eq(2)
    expect(analysis.summary.fetch("paid_content_available")).to be(false)
    expect(analysis).not_to be_meaningful_paid_content
  end

  it "imports missing shared spatial datasets before applying them to a located property" do
    analysis = create(:property_analysis)

    described_class.new(analysis).call

    expect(SpatialDataset.where(key: DataSources.config.dig("sofiaplan", "datasets").keys)
      .where.not(last_imported_at: nil).count).to eq(5)
    expect(analysis.source_runs.where("source_key LIKE ?", "sofiaplan_dataset_%").pluck(:status).uniq)
      .to eq([ "succeeded" ])
    expect(analysis.source_runs.find_by!(source_key: "openstreetmap_nearby_amenities").status).to eq("succeeded")
  end

  it "does not duplicate administrative acts on a repeated run" do
    analysis = create(:property_analysis)

    2.times { described_class.new(analysis).call }

    expect(AdministrativeAct.count).to eq(2)
  end

  it "does not claim that spatial datasets were applied without a reliable property location" do
    analysis = create(:property_analysis)
    allow(DataSources::Nag::LocationParser).to receive(:call).and_return({})

    described_class.new(analysis).call

    spatial_runs = analysis.source_runs.where("source_key LIKE ?", "sofiaplan_dataset_%")
    expect(spatial_runs).to exist
    expect(spatial_runs.pluck(:status).uniq).to eq([ "unavailable" ])
  end

  it "uses and preserves official cadastral geometry evidence" do
    factory = RGeo::Cartesian.preferred_factory(srid: 4326)
    ring = factory.linear_ring([
      factory.point(23.34, 42.63), factory.point(23.35, 42.63),
      factory.point(23.35, 42.64), factory.point(23.34, 42.64), factory.point(23.34, 42.63)
    ])
    geometry = factory.multi_polygon([ factory.polygon(ring) ])
    centroid = factory.point(23.345, 42.635)
    result = DataSources::Result.success(
      data: { "subject_area_sqm" => 136.01, "geometry" => geometry, "centroid" => centroid },
      source_url: "https://kais.cadastre.bg/bg/OpenData", relevant_at: Time.zone.parse("2026-08-05")
    )
    provider = instance_double(Cadastre::Provider, locate: result)
    analysis = create(:property_analysis)

    described_class.new(analysis, cadastre_provider: provider).call

    expect(analysis.reload.location_precision).to eq("cadastral_geometry")
    expect(analysis.parcel_geometry.geometry_type.type_name).to eq("MultiPolygon")
    expect(analysis.source_runs.find_by!(source_key: "cadastre").parsed_payload).to include(
      "geometry" => include("type" => "MultiPolygon"),
      "centroid" => include("type" => "Point")
    )
  end

  it "accepts non-Sofia identifiers and reports limited coverage" do
    analysis = create(
      :property_analysis,
      submitted_identifier: "12345.2.3", settlement_code: "12345", parcel_identifier: "12345.2.3",
      building_identifier: nil, individual_object_identifier: nil, identifier_level: "parcel"
    )

    described_class.new(analysis).call

    expect(analysis.reload.status).to eq("partial")
    expect(analysis.summary.fetch("outside_sofia")).to be(true)
    expect(analysis).not_to be_meaningful_paid_content
  end
end
