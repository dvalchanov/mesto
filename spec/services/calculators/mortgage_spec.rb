require "rails_helper"

RSpec.describe Calculators::Mortgage do
  it "amortizes a zero-interest loan exactly" do
    result = described_class.new(principal_cents: 12_000_000, annual_interest_rate: "0", term_months: 120).call

    expect(result).to include(
      "complete" => true,
      "regular_payment_cents" => 100_000,
      "total_interest_cents" => 0,
      "final_payment_cents" => 100_000
    )
    expect(result["schedule"].last["closing_balance_cents"]).to eq(0)
    expect(result["schedule"].sum { _1["principal_cents"] }).to eq(12_000_000)
  end

  it "matches the standard annuity fixture and adjusts only the final installment" do
    result = described_class.new(principal_cents: 10_000_000, annual_interest_rate: "6", term_months: 360).call

    expect(result["regular_payment_cents"]).to eq(59_955)
    expect(result["final_payment_cents"]).to eq(60_000)
    expect(result["schedule"].last["closing_balance_cents"]).to eq(0)
    expect(result["schedule"].sum { _1["principal_cents"] }).to eq(10_000_000)
    expect(result["schedule"].sum { _1["interest_cents"] }).to eq(result["total_interest_cents"])
    expect(result["schedule"].none? { _1["closing_balance_cents"].negative? }).to be(true)
  end

  it "handles a zero principal safely" do
    result = described_class.new(principal_cents: 0, annual_interest_rate: "4", term_months: 12).call
    expect(result["regular_payment_cents"]).to eq(0)
    expect(result["schedule"].last["closing_balance_cents"]).to eq(0)
  end
end
