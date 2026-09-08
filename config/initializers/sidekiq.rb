redis_config = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

module Mesto
  module RecurringJobs
    NAME_PREFIX = "Mesto: ".freeze
    JOBS = {
      "#{NAME_PREFIX}refresh prepared data - daily at 03:00" => {
        cron: "0 3 * * * Europe/Sofia",
        class: "RefreshPreparedDataJob",
        queue: "ingestion",
        active_job: true,
        description: "Check due cadastral and supporting datasets and enqueue their imports"
      },
      "#{NAME_PREFIX}prune anonymous journeys - daily at 04:00" => {
        cron: "0 4 * * * Europe/Sofia",
        class: "PruneAnonymousJourneysJob",
        queue: "default",
        active_job: true,
        description: "Delete anonymous buyer journeys older than the configured retention period"
      }
    }.freeze

    def self.sync!
      Sidekiq::Cron::Job.load_from_hash!(JOBS)

      Sidekiq::Cron::Job.all.each do |job|
        job.destroy if job.name.start_with?(NAME_PREFIX) && !JOBS.key?(job.name)
      end
    end
  end
end

Sidekiq.configure_server do |config|
  config.redis = redis_config

  config.on(:startup) do
    Mesto::RecurringJobs.sync!
  end
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
