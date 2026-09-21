class PruneAnonymousJourneysJob < ApplicationJob
  queue_as :default

  def perform
    cutoff = Rails.application.config.x.anonymous_journey_retention_days.days.ago
    deleted = 0

    BuyerJourney.where(last_active_at: ...cutoff).find_each do |journey|
      journey.destroy!
      deleted += 1
    end

    BudgetScenario.where(updated_at: ...cutoff).find_each do |scenario|
      scenario.destroy!
      deleted += 1
    end

    deleted
  end
end
