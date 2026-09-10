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

  describe "#due_diligence_result_classes" do
    it "uses the report's restrained semantic palette" do
      expect(helper.due_diligence_result_classes("verified_in_report")).to eq("due-diligence-status--confirmed")
      expect(helper.due_diligence_result_classes("external_official_check")).to eq("due-diligence-status--review")
      expect(helper.due_diligence_result_classes("request_document")).to eq("due-diligence-status--attention")
      expect(helper.due_diligence_result_classes("professional_review")).to eq("due-diligence-status--professional")
    end
  end

  describe "#property_graph_status_classes" do
    it "uses restrained report-specific status treatments" do
      expect(helper.property_graph_status_classes("exact")).to eq("property-graph__status--direct")
      expect(helper.property_graph_status_classes("supported")).to eq("property-graph__status--context")
      expect(helper.property_graph_status_classes("conflicting")).to eq("property-graph__status--conflict")
    end
  end

  describe "#source_result_classes" do
    it "uses the report's muted source-status palette" do
      expect(helper.source_result_classes("records_found")).to eq("source-result--positive")
      expect(helper.source_result_classes("used_for_calculation")).to eq("source-result--calculation")
      expect(helper.source_result_classes("restricted_access")).to eq("source-result--neutral")
      expect(helper.source_result_classes("unavailable")).to eq("source-result--attention")
      expect(helper.source_result_classes("failed")).to eq("source-result--failure")
    end
  end

  describe "#property_graph_edge_groups" do
    it "puts property rights before supporting context" do
      edges = [
        { "relationship_type" => "related_planning_record" },
        { "relationship_type" => "managed_by" },
        {
          "relationship_type" => "cadastre_right_holder",
          "subject_scope" => { "cadastral_identifier" => "68134.1" }
        },
        {
          "relationship_type" => "cadastre_right_holder",
          "subject_scope" => { "cadastral_identifier" => "68134.1.2.3" }
        }
      ]

      expect(helper.property_graph_edge_groups(edges, subject_identifier: "68134.1.2.3").map(&:first)).to eq(
        %w[property_rights parcel_rights related_parties property_context]
      )
    end
  end
end
