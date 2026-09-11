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
      { "key" => "area_missing", "status" => "needs_document", "topic_key" => "area_comparison" },
      { "key" => "location_missing", "status" => "needs_document", "topic_key" => "boundaries_access" },
      { "key" => "design_visa", "status" => "review", "topic_key" => "design_visa" },
      { "key" => "encumbrances", "status" => "not_checked", "topic_key" => "encumbrances" }
    )
  end
end
