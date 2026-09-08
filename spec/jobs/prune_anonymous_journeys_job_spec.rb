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
end
