require "rails_helper"

RSpec.describe DataSources::CadastreOpenData::ShpReader do
  it "streams polygon rings as BGS2005 multiline geometry" do
    ring = [ [ 500_000.0, 4_725_824.0 ], [ 500_010.0, 4_725_824.0 ],
      [ 500_010.0, 4_725_834.0 ], [ 500_000.0, 4_725_834.0 ], [ 500_000.0, 4_725_824.0 ] ]
    content = [ 5 ].pack("V") + [ 500_000.0, 4_725_824.0, 500_010.0, 4_725_834.0 ].pack("E4") +
      [ 1, ring.length, 0 ].pack("V3") + ring.flatten.pack("E*")
    file_length = 100 + 8 + content.bytesize
    header = [ 9994 ].pack("N") + ("\0" * 20) + [ file_length / 2 ].pack("N") +
      [ 1000, 5 ].pack("V2") + [ 500_000.0, 4_725_824.0, 500_010.0, 4_725_834.0, 0, 0, 0, 0 ].pack("E8")
    io = StringIO.new(header + [ 1, content.bytesize / 2 ].pack("N2") + content)

    expect(described_class.new(io).to_a).to eq([
      "MULTILINESTRING((500000.0 4725824.0,500010.0 4725824.0,500010.0 4725834.0,500000.0 4725834.0,500000.0 4725824.0))"
    ])
  end
end
