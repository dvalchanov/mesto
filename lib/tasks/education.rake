namespace :education do
  desc "Validate the version-controlled education catalog"
  task validate: :environment do
    catalog = Education::Catalog.new
    puts "Validated #{catalog.entries.size} education entries, #{catalog.rules.size} rules, and #{catalog.checklist_items.size} tasks."
  end

  desc "Delete anonymous buyer journeys beyond the configured retention period"
  task prune_anonymous_journeys: :environment do
    cutoff = Rails.application.config.x.anonymous_journey_retention_days.days.ago
    deleted = BuyerJourney.where(last_active_at: ...cutoff).delete_all
    puts "Deleted #{deleted} buyer journeys last active before #{cutoff.iso8601}."
  end
end
