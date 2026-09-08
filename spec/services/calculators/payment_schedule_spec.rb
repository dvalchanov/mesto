require "rails_helper"

RSpec.describe Calculators::PaymentSchedule do
  let(:events) do
    [
      { key: "first", label: "Първа вноска", order: 1, amount_type: "percentage", percentage: "10" },
      { key: "second", label: "Втора вноска", order: 2, amount_type: "percentage", percentage: "10" },
      { key: "closing", label: "Финална вноска", order: 3, amount_type: "remaining" }
    ]
  end

  it "credits a historical reservation once against the chosen installment" do
    result = described_class.new(property_price_cents: 30_000_000, events:, reservation: {
      amount_cents: 500_000, treatment: "credited", credit_event_key: "first", paid_before_start: true
    }).call

    first = result["events"].first
    expect(result["total_allocated_cents"]).to eq(30_000_000)
    expect(first).to include("total_cents" => 3_000_000, "reservation_credit_cents" => 500_000, "remaining_cents" => 2_500_000)
    expect(result["historical_price_paid_cents"]).to eq(500_000)
    expect(result["reservation_separate_fee_cents"]).to eq(0)
  end

  it "reports underallocation and overallocation without normalization" do
    under = described_class.new(property_price_cents: 10_000, events: [ { key: "one", amount_type: "percentage", percentage: "90" } ]).call
    over = described_class.new(property_price_cents: 10_000, events: [ { key: "one", amount_type: "percentage", percentage: "110" } ]).call

    expect(under["unallocated_cents"]).to eq(1_000)
    expect(over["overallocated_cents"]).to eq(1_000)
  end
end
