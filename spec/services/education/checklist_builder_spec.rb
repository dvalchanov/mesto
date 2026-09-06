require "rails_helper"

RSpec.describe Education::ChecklistBuilder do
  let(:journey) { create(:buyer_journey, buyer_stage: "waiting_or_payment") }
  let(:context) do
    {
      buyer_stage: "waiting_or_payment", property_type: "new_build", reported_milestone: "act14",
      evidenced_milestone: "unknown", financing_context: "undecided", source_coverage: "unavailable",
      property_connected: "no"
    }
  end

  it "separates applicability, evidence, and retained user progress" do
    create(:journey_item_progress, buyer_journey: journey, item_key: "task.check_payment_clause", status: "done", content_version: 1)
    items = described_class.new(journey:, context:).call
    payment = items.find { |item| item["key"] == "task.check_payment_clause" }

    expect(payment).to include("applicability" => "relevant_now", "user_progress" => "done")
    expect(payment.dig("evidence", "status")).to eq("professional_review_needed")
    expect(payment["title"]).to include("клаузата")
  end

  it "retains completed history and labels it when context changes" do
    create(:journey_item_progress, buyer_journey: journey, item_key: "task.check_payment_clause", status: "done", content_version: 1)
    owner_context = context.merge(buyer_stage: "owner")

    payment = described_class.new(journey:, context: owner_context).call.find { |item| item["key"] == "task.check_payment_clause" }

    expect(payment).to include("applicability" => "not_applicable", "user_progress" => "done")
  end
end
