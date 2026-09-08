require "rails_helper"

RSpec.describe Calculators::InputNormalizer do
  describe ".money_cents" do
    it "accepts Bulgarian decimal and grouping formats without binary floats" do
      expect(described_class.money_cents("300000")).to eq(30_000_000)
      expect(described_class.money_cents("300000.50")).to eq(30_000_050)
      expect(described_class.money_cents("300000,50")).to eq(30_000_050)
      expect(described_class.money_cents("300 000,50")).to eq(30_000_050)
      expect(described_class.money_cents("300\u00A0000,50")).to eq(30_000_050)
    end

    it "keeps blank distinct from zero" do
      expect(described_class.money_cents("")).to be_nil
      expect(described_class.money_cents("0")).to eq(0)
    end

    it "rejects ambiguous and malformed formats" do
      expect { described_class.money_cents("1.234") }.to raise_error(ArgumentError, "ambiguous_number")
      expect { described_class.money_cents("1,000.50") }.to raise_error(ArgumentError, "ambiguous_number")
      expect { described_class.money_cents("30 00,50") }.to raise_error(ArgumentError, "invalid_grouping")
    end
  end

  it "marks a selected blank cost unknown instead of converting it to zero" do
    normalizer = described_class.new
    inputs = normalizer.purchase(property_price: "100000", costs: {
      lawyer: { key: "lawyer", label: "Адвокат", included: "1", method: "fixed_quote", amount: "" }
    })
    result = Calculators::PurchaseCosts.new(inputs).call

    line = result["lines"].find { _1["key"] == "lawyer" }
    expect(line).to include("status" => "unresolved", "amount_cents" => 0)
    expect(result["complete"]).to be(false)
    expect(result["included_costs_cents"]).to be_positive
  end
end
