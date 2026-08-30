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
end
