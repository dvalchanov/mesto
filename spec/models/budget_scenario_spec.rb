require "rails_helper"

RSpec.describe BudgetScenario do
  it "keeps a reproducible snapshot and detects rule-version drift without silently updating it" do
    scenario = described_class.create!(
      guest_identity_digest: Digest::SHA256.hexdigest("guest"), title: "Сметка", currency: "EUR",
      input_schema_version: 1,
      validated_inputs: Calculators::InputNormalizer.new.purchase(property_price: "100000", transaction_date: "2026-09-06"),
      calculation_snapshot: { "complete" => false }, engine_version: "1.0.0",
      financial_rule_versions: { "old" => "version" }, calculated_at: Time.current
    )

    expect(scenario).to be_stale_rules
    expect(scenario.reload.financial_rule_versions).to eq("old" => "version")
  end

  it "uses an English suffix when duplicating a scenario in the English locale" do
    scenario = described_class.create!(
      guest_identity_digest: Digest::SHA256.hexdigest("guest-copy"), title: "My calculation", currency: "EUR",
      input_schema_version: 1,
      validated_inputs: Calculators::InputNormalizer.new.purchase(property_price: "100000", transaction_date: "2026-09-06"),
      calculation_snapshot: { "complete" => false }, engine_version: "1.0.0",
      financial_rule_versions: {}, calculated_at: Time.current
    )

    copy = I18n.with_locale(:en) { scenario.duplicate! }

    expect(copy.title).to eq("My calculation - copy")
  end
end
