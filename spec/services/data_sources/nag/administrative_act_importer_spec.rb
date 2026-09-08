require "rails_helper"

RSpec.describe DataSources::Nag::AdministrativeActImporter do
  let(:factory) { RGeo::Cartesian.preferred_factory(srid: 4326) }
  let(:identifier) { "68134.1000.2000" }

  it "derives a labelled location only from an explicit cadastral reference" do
    ring = factory.linear_ring([
      factory.point(23.32, 42.69), factory.point(23.321, 42.69),
      factory.point(23.321, 42.691), factory.point(23.32, 42.691),
      factory.point(23.32, 42.69)
    ])
    CadastralProperty.create!(
      cadastral_identifier: identifier,
      identifier_level: "parcel",
      geometry: factory.polygon(ring),
      source_archive_key: "district/parcels.zip",
      source_url: "https://kais.cadastre.bg/source"
    )

    act = described_class.call(record("explicit", "cadastral_identifiers" => [ identifier ]))

    expect(act.geometry).to be_present
    expect(act.properties).to include(
      "location_basis" => "cadastral_reference_representative_point",
      "location_reference" => identifier
    )
    expect(act.administrative_act_references.first).to have_attributes(
      cadastral_identifier: identifier,
      reference_level: "parcel",
      match_basis: "document"
    )
  end

  it "keeps a search hit distinct and does not invent its location" do
    act = described_class.call(record("search", "matched_identifier" => identifier))

    expect(act.geometry).to be_nil
    expect(act.properties.fetch("location_basis")).to eq("unavailable")
    expect(act.administrative_act_references.first.match_basis).to eq("search_query")
  end

  def record(key, extra)
    {
      "registry_kind" => "design_visas",
      "external_key" => key,
      "title" => "Test act",
      "source_url" => "https://nag.sofia.bg/example"
    }.merge(extra)
  end
end
