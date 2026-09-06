require "rails_helper"

RSpec.describe Education::Catalog do
  subject(:catalog) { described_class.new }

  it "loads and validates the complete initial Bulgarian library" do
    expect { Education::ContentValidator.new(catalog).validate! }.not_to raise_error
    expect(catalog.published("stage").size).to eq(8)
    expect(catalog.published("document").size).to be >= 28
    expect(catalog.published("term").size).to be >= 32
    expect(catalog.entries).to all(include("locale" => "bg", "professional_review_status" => "pending"))
  end

  it "organizes every term into the supported buyer-facing groups" do
    categories = catalog.published("term").map { |entry| entry["category"] }

    expect(categories).to all(be_in(Education::ContentValidator::TERM_CATEGORIES))
    expect(categories.uniq).to match_array(Education::ContentValidator::TERM_CATEGORIES)
  end

  it "organizes every document into a supported group with practical buyer checks" do
    documents = catalog.published("document")
    categories = documents.map { |entry| entry["category"] }

    expect(categories).to all(be_in(Education::ContentValidator::DOCUMENT_CATEGORIES))
    expect(categories.uniq).to match_array(Education::ContentValidator::DOCUMENT_CATEGORIES)
    expect(documents).to all(satisfy { |entry| entry.dig("sections", "buyer_checks").length >= 4 })
  end

  it "covers every navigable buyer stage and keeps property routes separate" do
    guides = catalog.published("guide")
    journey_guides = guides.select { |entry| entry["category"] == "buyer_journey" }
    property_guides = guides.select { |entry| entry["category"] == "property_type" }

    expect(guides.size).to eq(11)
    expect(journey_guides.map { |entry| entry["buyer_stage"] }).to match_array(BuyerJourney::GUIDED_BUYER_STAGES)
    expect(property_guides.flat_map { |entry| entry["property_types"] }).to contain_exactly("completed_home", "house", "land")
    expect(guides).to all(satisfy { |entry| entry.dig("sections", "buyer_checks").length >= 5 })
  end

  it "resolves every relationship and source without executable content" do
    catalog.entries.each do |entry|
      expect(entry.fetch("source_ids")).not_to be_empty
      entry.fetch("source_ids").each { |id| expect(catalog.source(id)).to be_present }
      %w[related_stage_keys related_document_keys related_term_keys].each do |field|
        Array(entry[field]).each { |key| expect(catalog.find(key)).to be_present }
      end
    end
    expect(catalog.rules.flat_map { |rule| rule.fetch("when", {}).keys }.uniq - Education::ContentValidator::CONDITION_KEYS).to be_empty
  end

  it "keeps article content substantive and stage checklists genuinely useful" do
    catalog.entries.each do |entry|
      minimum = Education::ContentValidator::MINIMUM_SECTION_CONTENT.fetch(entry["kind"])
      expect(entry.fetch("sections").values.flatten.join(" ").length).to be >= minimum
    end

    catalog.published("stage").each do |stage|
      expect(stage.dig("sections", "verify").length).to be >= 5
      expect(stage.fetch("content_version")).to be >= 2
    end
  end
end
