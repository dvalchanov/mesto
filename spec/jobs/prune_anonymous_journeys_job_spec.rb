require "rails_helper"

RSpec.describe PruneAnonymousJourneysJob do
  it "deletes journeys beyond the configured retention period" do
    expired = create(:buyer_journey, last_active_at: 181.days.ago)
    expired.journey_item_progresses.create!(item_key: "task.define_needs", item_kind: "task")
    current = create(:buyer_journey, last_active_at: 179.days.ago)

    expect { described_class.perform_now }
      .to change(BuyerJourney, :count).by(-1)
      .and change(JourneyItemProgress, :count).by(-1)

    expect(BuyerJourney.exists?(expired.id)).to be(false)
    expect(BuyerJourney.exists?(current.id)).to be(true)
  end

  it "deletes saved anonymous scenarios beyond the same retention period" do
    attributes = {
      guest_identity_digest: Digest::SHA256.hexdigest("anonymous"), title: "Scenario", currency: "EUR",
      input_schema_version: 1, validated_inputs: {}, calculation_snapshot: {}, engine_version: "1.0.0",
      financial_rule_versions: {}, calculated_at: Time.current
    }
    expired = BudgetScenario.create!(attributes)
    current = BudgetScenario.create!(attributes.merge(guest_identity_digest: Digest::SHA256.hexdigest("current")))
    expired.update_column(:updated_at, 181.days.ago)
    current.update_column(:updated_at, 179.days.ago)

    expect { described_class.perform_now }.to change(BudgetScenario, :count).by(-1)
    expect(BudgetScenario.exists?(expired.id)).to be(false)
    expect(BudgetScenario.exists?(current.id)).to be(true)
  end
end
