require "rails_helper"

RSpec.describe Calculators::ScenarioComparison do
  it "compares available metrics without declaring a winner" do
    first = { costs: { combined_included_outlay_cents: 100 }, mortgage: { regular_payment_cents: 20 } }
    second = { costs: { combined_included_outlay_cents: 120 }, mortgage: { regular_payment_cents: 15 } }

    result = described_class.new(first, second).call
    expect(result.dig("metrics", "included_outlay_cents", "difference")).to eq(20)
    expect(result.dig("metrics", "monthly_payment_cents", "difference")).to eq(-5)
  end
end
