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
      a_hash_including(
        "key" => "area_missing", "topic_key" => "area_comparison",
        "lookup_identifier" => analysis.submitted_identifier
      ),
      a_hash_including(
        "key" => "location_missing", "topic_key" => "boundaries_access",
        "lookup_identifier" => analysis.parcel_identifier
      ),
      a_hash_including(
        "key" => "design_visa", "topic_key" => "design_visa",
        "lookup_identifier" => analysis.parcel_identifier
      ),
      a_hash_including(
        "key" => "encumbrances", "topic_key" => "encumbrances",
        "lookup_identifier" => analysis.submitted_identifier
      )
    )
    expect(items.find { |item| item["key"] == "design_visa" }.fetch("known_facts")).to include(
      a_hash_including("key" => "matched_record", "format" => "administrative_act")
    )
  end

  it "prefills each applicable check with relevant facts already extracted by the report" do
    analysis = create(:property_analysis, status: "ready")
    facts = {
      "subject_area_sqm" => 67.3,
      "purpose" => "Жилище, апартамент",
      "address" => "гр. София, вх. А, ет. 2, ап. 8",
      "entrance" => "А",
      "floor" => "2",
      "object_number" => "8",
      "additional_parts" => "2.38% (10.43 кв.м.) общи части",
      "parcel_area_sqm" => 1879.63,
      "cadastre_records" => {
        "parcel" => {
          "area_sqm" => "1879.63", "regulation_parcel" => "II", "quarter" => "271",
          "permanent_use" => "Високо застрояване", "old_identifier" => "1659,2785"
        },
        "building" => { "area_sqm" => "1741.95", "floors_count" => 8, "purpose" => "Жилищна сграда" },
        "individual_object" => { "area_sqm" => "67.3" }
      }
    }

    items = described_class.new(analysis:, facts:).call.index_by { |item| item.fetch("topic_key") }

    expect(items.fetch("area_comparison").fetch("known_facts")).to include(
      { "key" => "subject_area", "value" => 67.3, "format" => "area" },
      { "key" => "position", "value" => { "entrance" => "А", "floor" => "2", "object_number" => "8" }, "format" => "text" },
      { "key" => "additional_parts", "value" => "2.38% (10.43 кв.м.) общи части", "format" => "text" }
    )
    expect(items.fetch("boundaries_access").fetch("known_facts")).to include(
      { "key" => "regulated_plot", "value" => { "regulated_plot" => "II", "quarter" => "271" }, "format" => "text" },
      { "key" => "previous_identifier", "value" => "1659,2785", "format" => "text" }
    )
    expect(items.fetch("occupancy").fetch("known_facts")).to include(
      { "key" => "building_floors", "value" => 8, "format" => "text" },
      { "key" => "building_footprint", "value" => "1741.95", "format" => "area" }
    )
    expect(items.fetch("title_chain").fetch("known_facts")).to include(
      { "key" => "subject_area", "value" => 67.3, "format" => "area" },
      { "key" => "address", "value" => "гр. София, вх. А, ет. 2, ап. 8", "format" => "text" }
    )
  end

  it "uses the building identifier for an occupancy search" do
    analysis = create(:property_analysis, status: "ready")

    occupancy = described_class.new(analysis:, facts: { "subject_area_sqm" => 82.4 }).call.find do |item|
      item.fetch("topic_key") == "occupancy"
    end

    expect(occupancy).to include("lookup_identifier" => analysis.building_identifier)
  end

  it "provides a complete three-step guide for every possible priority in both locales" do
    described_class::TOPIC_KEYS.values.uniq.each do |topic_key|
      %i[bg en].each do |locale|
        steps = I18n.t("reports.buyer_checklist.priority_guides.#{topic_key}.steps", locale:)
        warning = I18n.t("reports.buyer_checklist.priority_guides.#{topic_key}.watch", locale:)
        comparison = I18n.t("reports.buyer_checklist.priority_guides.#{topic_key}.compare_intro", locale:)

        expect(steps).to contain_exactly(instance_of(String), instance_of(String), instance_of(String))
        expect(warning).to be_present
        expect(comparison).to be_present
      end
    end
  end
end
