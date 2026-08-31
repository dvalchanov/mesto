require "rails_helper"

RSpec.describe Analysis::QuestionsBuilder do
  it "only adds signal-driven questions plus the official encumbrance question" do
    analysis = create(:property_analysis)
    builder = described_class.new(
      analysis:,
      metrics: { "direct_activity" => { "by_registry" => { "building_permits" => 1, "urban_planning_orders" => 0 } } }
    )

    expect(builder.call).to include("reports.questions.building_permit", "reports.questions.occupancy", "reports.questions.encumbrances")
    expect(builder.call).not_to include("reports.questions.planning_change")
  end
end
