require "rails_helper"

RSpec.describe Calculators::FundingLedger do
  def credited_schedule
    Calculators::PaymentSchedule.new(
      property_price_cents: 30_000_000,
      events: [
        { key: "first", label: "Първа", order: 1, amount_type: "percentage", percentage: "10" },
        { key: "second", label: "Втора", order: 2, amount_type: "percentage", percentage: "10" },
        { key: "notarial_transfer", label: "Сделка", order: 3, amount_type: "remaining" }
      ],
      reservation: { amount_cents: 500_000, treatment: "credited", credit_event_key: "first", paid_before_start: true }
    ).call
  end

  let(:closing_cost) do
    { key: "fees", status: "calculated", category: "acquisition", amount_cents: 1_000_000,
      already_paid_cents: 0, remaining_cents: 1_000_000, payment_event_key: "notarial_transfer" }
  end

  it "keeps historical payments out of current cash and exposes the required shortfall fixture" do
    result = described_class.new(schedule: credited_schedule, cost_lines: [ closing_cost ], mortgage_principal_cents: 24_000_000,
      funding: { starting_cash_cents: 6_000_000, reserve_cents: 0, mortgage_availability_event_key: "notarial_transfer", own_inflows: [] }).call

    expect(result).to include(
      "remaining_total_payments_cents" => 30_500_000,
      "remaining_own_funding_cents" => 6_500_000,
      "lifetime_own_funding_cents" => 7_000_000,
      "largest_funding_shortfall_cents" => 500_000
    )
    expect(result["rows"].map { _1["projected_own_cash_cents"] }).to eq([ 3_500_000, 500_000, -500_000 ])
  end

  it "finds a timing shortfall even when aggregate funding equals aggregate payments" do
    schedule = Calculators::PaymentSchedule.new(property_price_cents: 10_000_000, events: [
      { key: "early", label: "Ранно", order: 1, amount_type: "percentage", percentage: "50" },
      { key: "late", label: "Късно", order: 2, amount_type: "remaining" }
    ]).call
    result = described_class.new(schedule:, cost_lines: [], mortgage_principal_cents: 5_000_000,
      funding: { starting_cash_cents: 0, reserve_cents: 0, mortgage_availability_event_key: "late", own_inflows: [ { event_key: "late", amount_cents: 5_000_000 } ] }).call

    expect(result["remaining_total_payments_cents"]).to eq(10_000_000)
    expect(result["largest_funding_shortfall_cents"]).to eq(5_000_000)
    expect(result["first_shortfall_event_key"]).to eq("early")
  end

  it "distinguishes reserve erosion from inability to pay" do
    schedule = Calculators::PaymentSchedule.new(property_price_cents: 9_000_000,
      events: [ { key: "closing", label: "Сделка", order: 1, amount_type: "remaining" } ]).call
    result = described_class.new(schedule:, cost_lines: [], funding: {
      starting_cash_cents: 10_000_000, reserve_cents: 2_000_000, own_inflows: []
    }).call

    expect(result["largest_funding_shortfall_cents"]).to eq(0)
    expect(result["reserve_only_shortfall_cents"]).to eq(1_000_000)
    expect(result["remaining_total_payments_cents"]).to eq(9_000_000)
  end

  it "respects event order for same-day inflows" do
    schedule = Calculators::PaymentSchedule.new(property_price_cents: 10_000_000, events: [
      { key: "before", label: "Преди превода", order: 1, date: "2026-10-01", amount_type: "percentage", percentage: "50" },
      { key: "after", label: "След превода", order: 2, date: "2026-10-01", amount_type: "remaining" }
    ]).call
    result = described_class.new(schedule:, cost_lines: [], funding: {
      starting_cash_cents: 0, reserve_cents: 0, own_inflows: [ { event_key: "after", amount_cents: 10_000_000 } ]
    }).call

    expect(result["first_shortfall_event_key"]).to eq("before")
    expect(result["largest_funding_shortfall_cents"]).to eq(5_000_000)
  end

  it "keeps staged mortgage drawdowns restricted to seller payments" do
    schedule = Calculators::PaymentSchedule.new(property_price_cents: 10_000_000, events: [
      { key: "first", label: "Първа", order: 1, amount_type: "percentage", percentage: "40" },
      { key: "closing", label: "Сделка", order: 2, amount_type: "remaining" }
    ]).call
    fee = closing_cost.merge(amount_cents: 500_000, remaining_cents: 500_000, payment_event_key: "closing")
    result = described_class.new(schedule:, cost_lines: [ fee ], mortgage_principal_cents: 8_000_000, funding: {
      starting_cash_cents: 2_500_000, reserve_cents: 0,
      mortgage_disbursements: [
        { event_key: "first", amount_cents: 2_000_000 }, { event_key: "closing", amount_cents: 6_000_000 }
      ], own_inflows: []
    }).call

    expect(result["rows"].first).to include("mortgage_applied_cents" => 2_000_000, "own_cash_required_cents" => 2_000_000)
    expect(result["rows"].last).to include("mortgage_applied_cents" => 6_000_000, "additional_costs_cents" => 500_000, "own_cash_required_cents" => 500_000)
    expect(result["minimum_projected_cash_cents"]).to eq(0)
  end
end
