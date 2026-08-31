require "rails_helper"

RSpec.describe DataSources::CadastreOpenData::PropertyArchiveImporter do
  it "imports the buyer-relevant building and parcel hierarchy fields" do
    import_record(:buildings, building_fields, {
      "cadnum" => "68134.1609.3263.1", "AREA" => "841.84", "PERIM" => "130.88",
      "flrcount" => "4", "appcount" => "52", "functype" => "Жилищна сграда - многофамилна",
      "funccode" => "110", "proptype" => "Частна", "propcode" => "5"
    })
    import_record(:parcels, parcel_fields, {
      "cadnum" => "68134.1609.3263", "AREA" => "2500.38", "PERIM" => "201.62",
      "parcel" => "IX-3263", "quarter" => "51", "purptype" => "Урбанизирана",
      "purpcode" => "1", "usetype" => "Средно застрояване (от 10 до 15 m)", "usecode" => "1010"
    })

    building = CadastralProperty.find_by!(cadastral_identifier: "68134.1609.3263.1")
    parcel = CadastralProperty.find_by!(cadastral_identifier: "68134.1609.3263")
    expect(building).to have_attributes(
      area_sqm: BigDecimal("841.84"), perimeter_m: BigDecimal("130.88"),
      floors_count: 4, objects_count: 52, purpose_code: "110", ownership_type: "Частна"
    )
    expect(parcel).to have_attributes(
      area_sqm: BigDecimal("2500.38"), regulation_parcel: "IX-3263", quarter: "51",
      territory_type: "Урбанизирана", permanent_use_code: "1010"
    )
  end

  it "reconstructs and transforms the official cadastral polygon" do
    row = {
      "cadnum" => "68134.1609.3263", "AREA" => "100.00", "PERIM" => "40.00",
      "parcel" => "IX-3263", "quarter" => "51", "purptype" => "Урбанизирана",
      "purpcode" => "1", "usetype" => "Средно застрояване", "usecode" => "1010"
    }
    archive = Tempfile.new([ "cadastre-geometry", ".zip" ])
    archive.close
    Zip::File.open(archive.path, create: true) do |zip|
      zip.get_output_stream("data.dbf") { |io| io.write(build_dbf(parcel_fields, [ row ])) }
      zip.get_output_stream("data.shp") { |io| io.write(build_shp) }
      zip.get_output_stream("data.prj") { |io| io.write('PROJCS["BGS2005",PROJECTION["Lambert_Conformal_Conic"]]') }
    end

    described_class.new(
      archive_path: archive.path, source_archive_key: "district/parcels-geometry.zip",
      source_url: "https://kais.cadastre.bg/source", archive_kind: :parcels,
      relevant_at: Time.zone.parse("2026-08-05")
    ).call
    property = CadastralProperty.find_by!(cadastral_identifier: row.fetch("cadnum"))

    expect(property.source_geometry.geometry_type.type_name).to eq("MultiPolygon")
    expect(property.geometry.geometry_type.type_name).to eq("MultiPolygon")
    expect(property.properties.fetch("source_crs")).to eq("EPSG:7801 (BGS2005 / CCS2005)")
    expect(CadastralProperty.where(id: property.id).pick(Arel.sql("ST_Area(source_geometry)"))).to be_within(0.01).of(100)
  ensure
    archive&.unlink
  end

  def import_record(kind, fields, row)
    archive = Tempfile.new([ "cadastre-#{kind}", ".zip" ])
    archive.close
    Zip::File.open(archive.path, create: true) do |zip|
      zip.get_output_stream("data.dbf") { |io| io.write(build_dbf(fields, [ row ])) }
    end
    described_class.new(
      archive_path: archive.path, source_archive_key: "district/#{kind}.zip",
      source_url: "https://kais.cadastre.bg/source", archive_kind: kind,
      relevant_at: Time.zone.parse("2026-08-05")
    ).call
  ensure
    archive&.unlink
  end

  def building_fields
    [ [ "cadnum", "C", 30, 0 ], [ "AREA", "N", 15, 2 ], [ "PERIM", "N", 15, 2 ],
      [ "flrcount", "N", 3, 0 ], [ "appcount", "N", 5, 0 ], [ "functype", "C", 60, 0 ],
      [ "funccode", "C", 5, 0 ], [ "proptype", "C", 20, 0 ], [ "propcode", "C", 5, 0 ] ]
  end

  def parcel_fields
    [ [ "cadnum", "C", 30, 0 ], [ "AREA", "N", 15, 2 ], [ "PERIM", "N", 15, 2 ],
      [ "parcel", "C", 20, 0 ], [ "quarter", "C", 10, 0 ], [ "purptype", "C", 30, 0 ],
      [ "purpcode", "C", 5, 0 ], [ "usetype", "C", 60, 0 ], [ "usecode", "C", 8, 0 ] ]
  end

  def build_dbf(fields, rows)
    header_length = 32 + (fields.length * 32) + 1
    record_length = 1 + fields.sum { |field| field[2] }
    header = "\x03" + [ 126, 8, 5 ].pack("C3") + [ rows.length ].pack("V") +
      [ header_length, record_length ].pack("v2") + ("\0" * 20)
    descriptors = fields.map do |name, type, length, decimals|
      name.ljust(11, "\0") + type + ("\0" * 4) + [ length, decimals ].pack("C2") + ("\0" * 14)
    end.join
    records = rows.map do |record|
      " " + fields.map do |name, type, length, _decimals|
        value = record.fetch(name).to_s.b
        type == "N" ? value.rjust(length) : value.ljust(length)
      end.join
    end.join
    header + descriptors + "\r" + records + "\x1a"
  end

  def build_shp
    ring = [ [ 500_000.0, 4_725_824.0 ], [ 500_010.0, 4_725_824.0 ],
      [ 500_010.0, 4_725_834.0 ], [ 500_000.0, 4_725_834.0 ], [ 500_000.0, 4_725_824.0 ] ]
    content = [ 5 ].pack("V") + [ 500_000.0, 4_725_824.0, 500_010.0, 4_725_834.0 ].pack("E4") +
      [ 1, ring.length, 0 ].pack("V3") + ring.flatten.pack("E*")
    file_length = 100 + 8 + content.bytesize
    header = [ 9994 ].pack("N") + ("\0" * 20) + [ file_length / 2 ].pack("N") +
      [ 1000, 5 ].pack("V2") + [ 500_000.0, 4_725_824.0, 500_010.0, 4_725_834.0, 0, 0, 0, 0 ].pack("E8")
    header + [ 1, content.bytesize / 2 ].pack("N2") + content
  end
end
