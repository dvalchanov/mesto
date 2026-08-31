require "rails_helper"

RSpec.describe Analysis::BuyerChecklistBuilder do
  it "turns missing facts and public findings into buyer actions" do
    analysis = create(:property_analysis, status: "partial")
    visa = create(:administrative_act, registry_kind: "design_visas")
    visa.administrative_act_references.create!(
      cadastral_identifier: analysis.parcel_identifier, reference_level: "parcel"
    )

    items = described_class.new(analysis:, facts: { "subject_area_sqm" => nil }).call

    expect(items).to include(
      { "key" => "area_missing", "status" => "needs_document" },
      { "key" => "location_missing", "status" => "needs_document" },
      { "key" => "design_visa", "status" => "review" },
      { "key" => "encumbrances", "status" => "not_checked" }
    )
  end
end
