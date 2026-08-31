require "rails_helper"

RSpec.describe DataSources::CadastreOpenData::IndividualObjectsImporter do
  it "imports official object area and identity facts from an AGKK archive" do
    archive = Tempfile.new([ "cadastre-spec", ".zip" ])
    archive.close
    Zip::File.open(archive.path, create: true) do |zip|
      zip.get_output_stream("objects.dbf") { |io| io.write(dbf_fixture) }
    end

    result = described_class.new(
      archive_path: archive.path, source_archive_key: "district/objects.zip",
      source_url: "https://kais.cadastre.bg/bg/OpenData/Download?path=objects",
      relevant_at: Time.zone.parse("2026-08-05")
    ).call
    property = CadastralProperty.find_by!(cadastral_identifier: "68134.1609.3263.1.10")

    expect(result).to have_attributes(status: "succeeded", records_imported: 1)
    expect(property).to have_attributes(
      area_sqm: BigDecimal("136.01"), object_number: "А-10", floor: "2",
      levels_count: 1, purpose: "Жилище, апартамент"
    )
  ensure
    archive&.unlink
  end

  def dbf_fixture
    fields = [
      [ "cadnum", "C", 30, 0 ], [ "apparea", "N", 15, 2 ], [ "appnum", "C", 20, 0 ],
      [ "flrnum", "C", 5, 0 ], [ "flrcount", "N", 3, 0 ], [ "apptype", "C", 40, 0 ]
    ]
    row = {
      "cadnum" => "68134.1609.3263.1.10", "apparea" => "136.01", "appnum" => "А-10",
      "flrnum" => "2", "flrcount" => "1", "apptype" => "Жилище, апартамент"
    }
    build_dbf(fields, [ row ])
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
end
