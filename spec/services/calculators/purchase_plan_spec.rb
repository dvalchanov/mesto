require "rails_helper"

RSpec.describe Calculators::PurchasePlan do
  it "derives the loan from explicit valuation and financing assumptions when principal is blank" do
    inputs = Calculators::InputNormalizer.new.purchase(
      property_price: "100000", tax_assessment: "90000", financing_mode: "mortgage",
      bank_valuation: "80000", assumed_financing_percentage: "75", annual_interest_rate: "0", term_years: "10",
      starting_cash: "50000", mortgage_availability_event_key: "closing",
      schedule: { closing: { key: "closing", label: "Сделка", order: "1", amount_type: "remaining" } }
    )
    result = described_class.new(inputs).call

    expect(result.dig("mortgage", "principal_cents")).to eq(6_000_000)
    expect(result.dig("mortgage", "regular_payment_cents")).to eq(50_000)
  end

  it "derives principal from an explicitly selected contribution toward price" do
    inputs = Calculators::InputNormalizer.new.purchase(
      property_price: "100000", tax_assessment: "90000", financing_mode: "mortgage",
      loan_primary_input: "own_contribution", own_contribution: "25000", annual_interest_rate: "0", term_years: "10"
    )

    expect(described_class.new(inputs).call.dig("mortgage", "principal_cents")).to eq(7_500_000)
  end
end
