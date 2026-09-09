redis_config = Mesto::RedisConnection.options

module Mesto
  module RecurringJobs
    NAME_PREFIX = "Mesto: ".freeze
    JOBS = {
      "#{NAME_PREFIX}refresh prepared data - Sundays at 03:00" => {
        cron: "0 3 * * 0 Europe/Sofia",
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
  config.redis = redis_config.merge(size: ENV.fetch("SIDEKIQ_REDIS_POOL", 3).to_i)

  config.capsule("ingestion") do |capsule|
    capsule.concurrency = ENV.fetch("INGESTION_CONCURRENCY", 1).to_i
    capsule.queues = [ "ingestion" ]
  end

  config.on(:startup) do
    Mesto::RecurringJobs.sync!
  end
end

Sidekiq.configure_client do |config|
  config.redis = redis_config.merge(size: ENV.fetch("SIDEKIQ_CLIENT_REDIS_POOL", 2).to_i)
end
