require "rails_helper"

RSpec.describe "Production data-source permission gating" do
  before { allow(Rails.env).to receive(:production?).and_return(true) }

  it "exposes only approved prepared spatial datasets" do
    approved = SpatialDataset.create!(
      key: "approved_source", name: "Approved", provider: "Provider",
      source_url: "https://example.com/approved", last_imported_at: Time.current,
      permission_status: "approved"
    )
    SpatialDataset.create!(
      key: "review_source", name: "Review", provider: "Provider",
      source_url: "https://example.com/review", last_imported_at: Time.current,
      permission_status: "review_required"
    )

    expect(SpatialDataset.usable).to contain_exactly(approved)
  end

  it "gates cadastral geometry and rights by each exact approved archive" do
    profile_key = DataCoverage.profile.key
    geometry_archive = CadastreSourceArchive.create!(
      source_archive_key: "approved/parcels.zip", district: "Test", object_kind: "parcels",
      source_url: "https://kais.cadastre.bg/approved-parcels", coverage_profile_key: profile_key,
      permission_status: "approved"
    )
    review_geometry_archive = CadastreSourceArchive.create!(
      source_archive_key: "review/buildings.zip", district: "Test", object_kind: "buildings",
      source_url: "https://kais.cadastre.bg/review-buildings", coverage_profile_key: profile_key,
      permission_status: "review_required"
    )
    rights_archive = CadastreSourceArchive.create!(
      source_archive_key: "approved/parcel-rights.zip", district: "Test", object_kind: "parcel_rights",
      source_url: "https://kais.cadastre.bg/approved-rights", coverage_profile_key: profile_key,
      permission_status: "approved"
    )

    approved_property = CadastralProperty.create!(
      cadastral_identifier: "68134.1.1", identifier_level: "parcel",
      source_archive_key: geometry_archive.source_archive_key, source_url: geometry_archive.source_url
    )
    CadastralProperty.create!(
      cadastral_identifier: "68134.1.1.1", identifier_level: "building",
      source_archive_key: review_geometry_archive.source_archive_key, source_url: review_geometry_archive.source_url
    )
    approved_right = CadastreRight.create!(
      cadastral_identifier: approved_property.cadastral_identifier, identifier_level: "parcel",
      right_type: "ownership", holder_type: "company", holder_name: "Example EOOD",
      holder_entity_type: "company", holder_identifier: "175074752",
      source_archive_key: rights_archive.source_archive_key, source_url: rights_archive.source_url,
      record_fingerprint: SecureRandom.hex(32)
    )

    expect(CadastralProperty.usable).to contain_exactly(approved_property)
    expect(CadastreRight.usable).to contain_exactly(approved_right)
  end

  it "does not configure cadastral lookup without an approved geometry archive" do
    expect(Cadastre::Provider.configured).to be_a(Cadastre::NullProvider)
  end

  it "does not expose prepared NAG acts while the source remains under review" do
    analysis = create(:property_analysis)
    act = create(:administrative_act)
    act.administrative_act_references.create!(
      cadastral_identifier: analysis.parcel_identifier,
      reference_level: "parcel",
      match_basis: "document"
    )

    expect(analysis.administrative_acts).to be_empty
  end
end
