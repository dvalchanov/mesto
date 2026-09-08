require "rails_helper"

RSpec.describe Calculators::RuleCatalog do
  subject(:catalog) { described_class.new }

  it "selects versioned rules by effective date" do
    expect(catalog.find("bg.sofia.acquisition_tax", date: Date.new(2026, 9, 6), municipality: "sofia")).to include(
      "version" => "2026-01-01.1", "source_verification" => "primary_source_checked",
      "review_status" => "professional_review_pending"
    )
    expect { catalog.find("bg.sofia.acquisition_tax", date: Date.new(2025, 12, 31), municipality: "sofia") }
      .to raise_error(Calculators::RuleCatalog::RuleNotFound)
  end

  it "calculates the progressive notarial tariff after one fixed-rate conversion" do
    rule = catalog.find("bg.notary.material_interest", date: Date.new(2026, 9, 6))
    conversion = catalog.find("bg.euro_conversion", date: Date.new(2026, 9, 6))
    tariff = Calculators::ProgressiveNotarialFee.new(rule:, conversion_rule: conversion)

    expect(tariff.call(10_000_000)).to eq(47_124) # €100k -> BGN 195,583 -> BGN 921.666 -> €471.24
    expect(tariff.call(30_000_000)).to eq(82_689) # €300k -> BGN 586,749 -> BGN 1,617.249 -> €826.89
    expect(tariff.call(500_000_000)).to eq(306_775) # BGN 6,000 statutory cap converted once
  end


  it "covers every progressive tariff band without flattening it to a percentage" do
    rule = catalog.find("bg.notary.material_interest", date: Date.new(2026, 9, 6))
    conversion = catalog.find("bg.euro_conversion", date: Date.new(2026, 9, 6))
    tariff = Calculators::ProgressiveNotarialFee.new(rule:, conversion_rule: conversion)

    expect([ 10, 100, 1_000, 10_000, 50_000, 100_000, 300_000 ].map { tariff.call(_1 * 100) })
      .to eq([ 1_534, 1_607, 2_859, 12_116, 36_785, 47_124, 82_689 ])
    expect(rule.dig("parameters", "brackets").map { _1["up_to_bgn"] }).to eq(
      [ "100", "1000", "10000", "50000", "100000", "500000", nil ]
    )
  end
end
