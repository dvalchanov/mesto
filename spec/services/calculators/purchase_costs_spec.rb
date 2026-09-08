require "rails_helper"

RSpec.describe Calculators::PurchaseCosts do
  def normalize(raw)
    Calculators::InputNormalizer.new.purchase(raw)
  end

  it "uses the higher price/tax-assessment base for verified Sofia statutory lines" do
    result = described_class.new(normalize(property_price: "300000", tax_assessment: "320000", municipality: "sofia")).call

    expect(result["tax_base_cents"]).to eq(32_000_000)
    expect(result["lines"].find { _1["key"] == "municipal_acquisition_tax" }["amount_cents"]).to eq(960_000)
    expect(result["lines"].find { _1["key"] == "sale_registration_fee" }["amount_cents"]).to eq(32_000)
  end

  it "does not silently use Sofia's rate for another municipality" do
    result = described_class.new(normalize(property_price: "100000", municipality: "other")).call
    tax = result["lines"].find { _1["key"] == "municipal_acquisition_tax" }

    expect(tax["status"]).to eq("unresolved")
    expect(result["complete"]).to be(false)
  end

  it "accepts an explicitly labeled manual local-tax rate outside Sofia" do
    result = described_class.new(normalize(property_price: "100000", municipality: "other", manual_local_tax_rate: "2,5")).call
    tax = result["lines"].find { _1["key"] == "municipal_acquisition_tax" }

    expect(tax).to include("amount_cents" => 250_000, "provenance" => "user_entered_percentage")
  end

  it "adds property VAT only for a confirmed net quote" do
    uncertain = described_class.new(normalize(property_price: "100000", price_vat_treatment: "net", property_vat_rate: "20")).call
    confirmed = described_class.new(normalize(property_price: "100000", price_vat_treatment: "net", property_vat_rate: "20", property_vat_confirmed: "1")).call

    expect(uncertain["lines"].find { _1["key"] == "property_vat" }["status"]).to eq("unresolved")
    expect(confirmed["payable_property_price_cents"]).to eq(12_000_000)
  end

  it "does not count included components twice and adds explicit additional components once" do
    result = described_class.new(normalize(property_price: "300000", components: {
      garage: { key: "garage", label: "Гараж", amount: "20000", price_relation: "included" },
      storage: { key: "storage", label: "Склад", amount: "5000", price_relation: "additional" }
    })).call

    expect(result["payable_property_price_cents"]).to eq(30_500_000)
  end

  it "replaces an estimate instead of stacking an all-inclusive quote on it" do
    result = described_class.new(normalize(property_price: "100000", costs: {
      package: { key: "package", label: "Пакет нотариални услуги", included: "1", method: "fixed_quote",
        amount: "1000", vat_treatment: "inclusive", replaces: [ "main_notarial_fee" ] }
    })).call

    expect(result["lines"].map { _1["key"] }).to include("package")
    expect(result["lines"].map { _1["key"] }).not_to include("main_notarial_fee", "main_notarial_fee_vat")
  end

  it "applies the converted registration minimum" do
    result = described_class.new(normalize(property_price: "1000")).call
    expect(result["lines"].find { _1["key"] == "sale_registration_fee" }["amount_cents"]).to eq(511)
  end

  it "applies an explicit buyer allocation as a visible planning assumption" do
    result = described_class.new(normalize(property_price: "100000", tax_assessment: "90000", transaction_cost_share: "50")).call

    expect(result["lines"].find { _1["key"] == "municipal_acquisition_tax" }["amount_cents"]).to eq(150_000)
    expect(result["warnings"].join).to include("50.0%", "не определя кой по закон дължи разхода")
  end

  it "includes a known quote while leaving uncertain VAT unresolved" do
    result = described_class.new(normalize(property_price: "100000", tax_assessment: "90000", costs: {
      lawyer: { key: "lawyer", label: "Адвокат", included: "1", method: "fixed_quote", amount: "1000", vat_treatment: "uncertain" }
    })).call

    expect(result["lines"].find { _1["key"] == "lawyer" }).to include("status" => "calculated", "amount_cents" => 100_000)
    expect(result["lines"].find { _1["key"] == "lawyer_vat" }["status"]).to eq("unresolved")
    expect(result["included_costs_cents"]).to be >= 100_000
  end

  it "counts a separate paid reservation once as lifetime cost" do
    result = described_class.new(normalize(property_price: "100000", tax_assessment: "90000",
      reservation: { amount: "2000", treatment: "separate_fee", paid_before_start: "1" })).call
    line = result["lines"].find { _1["key"] == "reservation_separate_fee" }

    expect(line).to include("amount_cents" => 200_000, "already_paid_cents" => 200_000, "remaining_cents" => 0)
    expect(result["acquisition_costs_cents"]).to be >= 200_000
  end
end
