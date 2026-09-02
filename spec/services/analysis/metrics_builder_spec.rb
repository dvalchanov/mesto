require "rails_helper"

RSpec.describe Analysis::MetricsBuilder do
  let(:point_factory) { RGeo::Geographic.spherical_factory(srid: 4326) }
  let(:analysis) do
    create(
      :property_analysis,
      centroid: point_factory.point(23.3205, 42.6905),
      location_precision: "official_record_geometry"
    )
  end

  it "does not turn missing spatial checks into zeroes" do
    create_dataset("schools")

    metrics = described_class.new(analysis:).call

    expect(metrics.dig("amenities", "availability", "schools")).to be(false)
    expect(metrics.dig("amenities", "schools")).to eq({})
    expect(metrics.dig("environment", "available")).to be(false)
  end

  it "calculates counts only from succeeded dated datasets and separates existing from planned metro" do
    school_dataset = create_dataset("schools")
    transit_dataset = create_dataset("transit")
    %w[schools transit].each do |category|
      analysis.source_runs.create!(source_key: "sofiaplan_dataset_#{category}", status: "succeeded")
    end
    school_dataset.spatial_features.create!(
      external_key: "school", category: "schools", name: "Test school",
      geometry: point_factory.point(23.321, 42.691)
    )
    transit_dataset.spatial_features.create!(
      external_key: "existing", category: "transit", name: "Existing station",
      geometry: point_factory.point(23.322, 42.691), properties: { "layer" => "existing" }
    )
    transit_dataset.spatial_features.create!(
      external_key: "planned", category: "transit", name: "Planned station",
      geometry: point_factory.point(23.321, 42.6907), properties: { "layer" => "planned" }
    )

    metrics = described_class.new(analysis:).call

    expect(metrics.dig("amenities", "schools", "500")).to eq(1)
    expect(metrics.dig("amenities", "nearest_school", "name")).to eq("Test school")
    expect(metrics.dig("amenities", "nearest_existing_transit", "name")).to eq("Existing station")
    expect(metrics.dig("amenities", "nearest_planned_transit", "name")).to eq("Planned station")
  end

  it "prefers current bounded OpenStreetMap places over historical amenity snapshots" do
    analysis.update!(centroid: point_factory.point(23.3460262, 42.6394047))
    result = DataSources::OpenStreetMap::NearbyAmenitiesClient.new.fetch(centroid: analysis.centroid)
    analysis.source_runs.create!(
      source_key: "openstreetmap_nearby_amenities",
      status: "succeeded",
      parsed_payload: result.data,
      source_url: result.source_url,
      fetched_at: result.fetched_at,
      relevant_at: result.relevant_at
    )

    metrics = described_class.new(analysis:).call

    expect(metrics.dig("amenities", "places_source")).to eq("openstreetmap")
    expect(metrics.dig("amenities", "kindergartens")).to eq("500" => 1, "1000" => 2, "2000" => 3)
    expect(metrics.dig("amenities", "schools")).to eq("500" => 0, "1000" => 0, "2000" => 0)
    expect(metrics.dig("amenities", "nearest_kindergarten", "name")).to eq("ДГ №190")
  end

  it "does not calculate nearby activity or development pressure from identifier-only searches" do
    metrics = described_class.new(analysis:).call

    expect(metrics.fetch("nearby_activity")).to eq(
      "available" => false, "reason" => "identifier_search_only"
    )
    expect(metrics.fetch("development_pressure")).to eq(
      "level" => "unavailable", "reason" => "identifier_search_only"
    )
  end

  def create_dataset(key)
    SpatialDataset.create!(
      key:, name: key.humanize, provider: "SofiaPlan",
      source_url: "https://api.sofiaplan.bg/datasets/test-#{key}",
      relevant_at: Time.zone.parse("2020-01-01"), last_imported_at: Time.current
    )
  end
end
