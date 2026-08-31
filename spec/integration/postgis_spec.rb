require "rails_helper"

RSpec.describe "PostGIS configuration" do
  let(:connection) { ActiveRecord::Base.connection }
  let(:table_name) { :postgis_adapter_checks }

  after do
    connection.drop_table(table_name, if_exists: true)
  end

  it "enables PostGIS and supports geography and geometry columns" do
    expect(connection.extension_enabled?("postgis")).to be(true)

    connection.create_table(table_name, temporary: true) do |table|
      table.st_point :location, geographic: true, srid: 4326
      table.geometry :boundary, geographic: false, srid: 4326
    end

    columns = connection.columns(table_name).index_by(&:name)

    expect(columns.fetch("location").sql_type).to eq("geography(Point,4326)")
    expect(columns.fetch("boundary").sql_type).to eq("geometry(Geometry,4326)")
  end

  it "calculates radii, nearest features, intersections, and polygon touches" do
    factory = RGeo::Geographic.spherical_factory(srid: 4326)
    dataset = SpatialDataset.create!(key: "spatial-test", name: "Spatial test", provider: "Test", source_url: "https://api.sofiaplan.bg/datasets/test")
    origin = factory.point(23.32, 42.69)
    near_point = factory.point(23.3205, 42.6905)
    far_point = factory.point(23.40, 42.75)
    near_feature = dataset.spatial_features.create!(external_key: "near", category: "schools", name: "Near", geometry: near_point)
    dataset.spatial_features.create!(external_key: "far", category: "schools", name: "Far", geometry: far_point)

    expect(SpatialFeature.where(spatial_dataset: dataset).within(origin, 500)).to contain_exactly(near_feature)
    expect(SpatialFeature.where(spatial_dataset: dataset).in_category("schools").nearest_to(origin).first).to eq(near_feature)
    expect(near_feature.distance_to(origin)).to be_between(60, 80)

    left = RGeo::Cartesian.preferred_factory(srid: 4326).parse_wkt("POLYGON((23.31 42.68,23.32 42.68,23.32 42.69,23.31 42.69,23.31 42.68))")
    right = RGeo::Cartesian.preferred_factory(srid: 4326).parse_wkt("POLYGON((23.32 42.68,23.33 42.68,23.33 42.69,23.32 42.69,23.32 42.68))")
    flood = dataset.spatial_features.create!(external_key: "flood", category: "flood_risk", name: "Flood", geometry: left)
    neighbour = dataset.spatial_features.create!(external_key: "neighbour", category: "parcel", name: "Neighbour", geometry: right)

    expect(SpatialFeature.where(spatial_dataset: dataset).in_category("flood_risk").intersecting(left).first).to eq(flood)
    touching = SpatialFeature.where(id: neighbour.id).where("ST_Touches(geometry, ST_GeomFromText(?, 4326))", left.as_text)
    expect(touching).to contain_exactly(neighbour)
  end

  it "returns empty spatial scopes when geometry is unavailable" do
    expect(SpatialFeature.within(nil, 500)).to be_empty
    expect(SpatialFeature.intersecting(nil)).to be_empty
    expect(AdministrativeAct.near(nil, 100)).to be_empty
  end
end
