require "rails_helper"

RSpec.describe Education::RecommendationEngine do
  let(:context) do
    {
      buyer_stage: "before_deposit", property_type: "new_build", reported_milestone: "unknown",
      evidenced_milestone: "commissioning", financing_context: "mortgage", source_coverage: "available",
      property_connected: "yes"
    }
  end

  it "prioritizes evidence and the buyer-declared stage without duplicate lessons" do
    recommendations = described_class.new(context).call(limit: 20)
    keys = recommendations.map { |item| item["key"] }

    expect(keys.first).to eq("document.commissioning")
    expect(keys).to include("guide.before_deposit", "building.commissioning")
    expect(keys).to eq(keys.uniq)
    expect(recommendations).to all(include("reason", "priority"))
  end
end
