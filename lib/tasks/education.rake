namespace :education do
  desc "Validate the version-controlled education catalog"
  task validate: :environment do
    catalog = Education::Catalog.new
    puts "Validated #{catalog.entries.size} education entries, #{catalog.rules.size} rules, and #{catalog.checklist_items.size} tasks."
  end

  desc "Delete anonymous buyer journeys beyond the configured retention period"
  task prune_anonymous_journeys: :environment do
    deleted = PruneAnonymousJourneysJob.perform_now
    puts "Deleted #{deleted} expired anonymous buyer journeys."
  end
end
