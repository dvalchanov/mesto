require "rails_helper"

RSpec.describe Education::Catalog do
  subject(:catalog) { described_class.new }

  it "loads and validates the complete initial Bulgarian library" do
    expect { Education::ContentValidator.new(catalog).validate! }.not_to raise_error
    expect(catalog.published("stage").size).to eq(8)
    expect(catalog.published("document").size).to be >= 12
    expect(catalog.published("term").size).to be >= 6
    expect(catalog.entries).to all(include("locale" => "bg", "professional_review_status" => "pending"))
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
