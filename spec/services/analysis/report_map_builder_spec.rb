require "rails_helper"

RSpec.describe Analysis::ReportMapBuilder do
  let(:factory) { RGeo::Cartesian.preferred_factory(srid: 4326) }
  let(:point_factory) { RGeo::Geographic.spherical_factory(srid: 4326) }
  let(:source) do
    {
      source_archive_key: "district/map.zip",
      source_url: "https://kais.cadastre.bg/source",
      source_relevant_at: Time.zone.parse("2026-08-05")
    }
  end

  def polygon(west, south, east, north)
    ring = factory.linear_ring([
      factory.point(west, south), factory.point(east, south),
      factory.point(east, north), factory.point(west, north),
      factory.point(west, south)
    ])
    factory.polygon(ring)
  end

  def feature_properties(payload)
    payload.fetch(:features).map do |feature|
      (feature[:properties] || feature.fetch("properties")).symbolize_keys
    end
  end

  it "maps the exact cadastral hierarchy and nearby buildings without inventing context" do
    analysis = create(
      :property_analysis,
      status: "partial",
      centroid: point_factory.point(23.3205, 42.6905),
      location_precision: "cadastral_geometry"
    )
    CadastralProperty.create!(
      **source,
      cadastral_identifier: analysis.parcel_identifier,
      identifier_level: "parcel",
      geometry: polygon(23.319, 42.689, 23.322, 42.692)
    )
    CadastralProperty.create!(
      **source,
      cadastral_identifier: analysis.building_identifier,
      identifier_level: "building",
      floors_count: 6,
      geometry: polygon(23.3201, 42.6901, 23.3209, 42.6909)
    )
    CadastralProperty.create!(
      **source,
      cadastral_identifier: analysis.individual_object_identifier,
      identifier_level: "individual_object",
      purpose: "Apartment",
      geometry: polygon(23.3202, 42.6902, 23.3206, 42.6906)
    )
    nearby = CadastralProperty.create!(
      **source,
      cadastral_identifier: "68134.1000.2001.1",
      identifier_level: "building",
      geometry: polygon(23.321, 42.691, 23.3215, 42.6915)
    )
    outside_radius = CadastralProperty.create!(
      **source,
      cadastral_identifier: "68134.1000.2999.1",
      identifier_level: "building",
      geometry: polygon(23.323, 42.6903, 23.3233, 42.6907)
    )

    properties = feature_properties(described_class.new(analysis:).call)

    expect(properties.pluck(:kind)).to include(
      "parcel", "selected_building", "selected_object", "nearby_building", "selected_location"
    )
    expect(properties).to include(include(kind: "nearby_building", label: nearby.cadastral_identifier))
    expect(properties).not_to include(include(label: outside_radius.cadastral_identifier))
    expect(properties).not_to include(include(kind: "amenity"))
  end

  it "adds available neighborhood and register overlays to an unlocked report" do
    analysis = create(
      :property_analysis,
      status: "partial",
      centroid: point_factory.point(23.3205, 42.6905),
      location_precision: "official_record_geometry",
      summary: {
        "planning" => [
          {
            "source_key" => "arcgis_functional_zoning",
            "features" => [
              {
                "type" => "Feature",
                "geometry" => RGeo::GeoJSON.encode(polygon(23.319, 42.689, 23.322, 42.692)),
                "properties" => { "zone" => "Residential" }
              }
            ]
          }
        ]
      }
    )
    gateway = Payments::FakeGateway.new
    order = gateway.create_order(property_analysis: analysis, email: "map@example.com")
    gateway.succeed(order)

    dataset = SpatialDataset.create!(
      key: "map-schools",
      name: "Schools",
      provider: "SofiaPlan",
      source_url: "https://api.sofiaplan.bg/datasets/166",
      relevant_at: Time.zone.parse("2018-08-08")
    )
    school = dataset.spatial_features.create!(
      external_key: "school-1",
      category: "schools",
      name: "Example school",
      geometry: point_factory.point(23.321, 42.691)
    )
    analysis.source_runs.create!(source_key: "sofiaplan_dataset_schools", status: "succeeded")
    act = create(
      :administrative_act,
      title: "Nearby permit",
      geometry: point_factory.point(23.3212, 42.6912)
    )

    properties = feature_properties(
      described_class.new(analysis:, acts: AdministrativeAct.where(id: act.id)).call
    )

    expect(properties).to include(
      include(kind: "amenity", category: "schools", label: school.name),
      include(kind: "planning", source_key: "arcgis_functional_zoning"),
      include(kind: "act", label: act.title)
    )
    expect(properties.find { |property| property[:label] == school.name }[:date_label]).to be_present
    expect(properties.find { |property| property[:label] == school.name }[:distance_label]).to be_present
  end

  it "adds imported everyday places without requiring an unlocked report" do
    analysis = create(
      :property_analysis,
      status: "partial",
      centroid: point_factory.point(23.3205, 42.6905),
      location_precision: "official_record_geometry"
    )
    dataset = SpatialDataset.create!(
      key: "map-kindergartens",
      name: "Kindergartens",
      provider: "SofiaPlan",
      source_url: "https://api.sofiaplan.bg/datasets/167",
      relevant_at: Time.zone.parse("2019-03-12")
    )
    kindergarten = dataset.spatial_features.create!(
      external_key: "kindergarten-1",
      category: "kindergartens",
      name: "Example kindergarten",
      geometry: point_factory.point(23.321, 42.691)
    )
    analysis.source_runs.create!(source_key: "sofiaplan_dataset_kindergartens", status: "succeeded")

    properties = feature_properties(described_class.new(analysis:).call)

    expect(analysis).not_to be_full_report_unlocked
    expect(properties).to include(
      include(
        kind: "amenity",
        category: "kindergartens",
        label: kindergarten.name,
        distance_label: be_present
      )
    )
  end

  it "maps current OpenStreetMap places with distances and direct provenance" do
    analysis = create(
      :property_analysis,
      status: "partial",
      centroid: point_factory.point(23.3460262, 42.6394047),
      location_precision: "cadastral_geometry"
    )
    result = DataSources::OpenStreetMap::NearbyAmenitiesClient.new.fetch(centroid: analysis.centroid)
    analysis.source_runs.create!(
      source_key: "openstreetmap_nearby_amenities",
      status: "succeeded",
      parsed_payload: result.data,
      source_url: result.source_url,
      fetched_at: result.fetched_at,
      relevant_at: result.relevant_at
    )

    properties = feature_properties(described_class.new(analysis:).call)

    expect(properties).to include(
      include(
        kind: "amenity",
        category: "kindergartens",
        label: "ДГ №190",
        source_url: "https://www.openstreetmap.org/way/1256636075",
        distance_label: be_present,
        date_label: be_present
      )
    )
    expect(properties).not_to include(include(label: "ДГ №16 „Приказен свят“"))
  end
end
