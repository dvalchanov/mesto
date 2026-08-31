require "rails_helper"

RSpec.describe DataSources::CadastreOpenData::DbfReader do
  it "streams DBF fields and records without loading the full file" do
    io = StringIO.new(build_dbf(
      [ [ "cadnum", "C", 30, 0 ], [ "apparea", "N", 15, 2 ] ],
      [ { "cadnum" => "68134.1609.3263.1.10", "apparea" => "136.01" } ]
    ))

    expect(described_class.new(io).to_a).to eq(
      [ { "cadnum" => "68134.1609.3263.1.10", "apparea" => "136.01" } ]
    )
  end

  def build_dbf(fields, rows)
    header_length = 32 + (fields.length * 32) + 1
    record_length = 1 + fields.sum { |field| field[2] }
    header = "\x03" + [ 126, 8, 5 ].pack("C3") + [ rows.length ].pack("V") +
      [ header_length, record_length ].pack("v2") + ("\0" * 20)
    descriptors = fields.map do |name, type, length, decimals|
      name.ljust(11, "\0") + type + ("\0" * 4) + [ length, decimals ].pack("C2") + ("\0" * 14)
    end.join
    records = rows.map do |row|
      " " + fields.map do |name, type, length, _decimals|
        value = row.fetch(name).to_s.b
        type == "N" ? value.rjust(length) : value.ljust(length)
      end.join
    end.join
    header + descriptors + "\r" + records + "\x1a"
  end
end
