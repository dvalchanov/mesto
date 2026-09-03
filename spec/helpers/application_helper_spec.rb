require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#amenity_dataset_current?" do
    let(:as_of) { Date.new(2026, 9, 2) }

    it "accepts amenity data no more than two years old" do
      expect(helper.amenity_dataset_current?({ "relevant_at" => "2024-09-02" }, as_of:)).to be(true)
    end

    it "rejects older or undated amenity data" do
      expect(helper.amenity_dataset_current?({ "relevant_at" => "2018-08-08" }, as_of:)).to be(false)
      expect(helper.amenity_dataset_current?({}, as_of:)).to be(false)
      expect(helper.amenity_dataset_current?({ "relevant_at" => "unknown" }, as_of:)).to be(false)
    end
  end
end
