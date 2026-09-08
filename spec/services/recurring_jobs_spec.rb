require "rails_helper"

RSpec.describe Mesto::RecurringJobs do
  describe ".sync!" do
    it "loads the version-controlled jobs and removes stale Mesto jobs" do
      current_job = instance_double(Sidekiq::Cron::Job, name: described_class::JOBS.keys.first)
      stale_job = instance_double(Sidekiq::Cron::Job, name: "Mesto: removed job")
      unrelated_job = instance_double(Sidekiq::Cron::Job, name: "Another app: hourly job")

      allow(Sidekiq::Cron::Job).to receive(:load_from_hash!)
      allow(Sidekiq::Cron::Job).to receive(:all).and_return([ current_job, stale_job, unrelated_job ])
      allow(stale_job).to receive(:destroy)

      described_class.sync!

      expect(Sidekiq::Cron::Job).to have_received(:load_from_hash!).with(described_class::JOBS)
      expect(stale_job).to have_received(:destroy)
    end

    it "defines every recurring task as an Active Job in an existing queue" do
      expect(described_class::JOBS.values).to all(include(active_job: true))
      expect(described_class::JOBS.values.pluck(:queue)).to contain_exactly("ingestion", "default")
      expect(described_class::JOBS.values.pluck(:class)).to contain_exactly(
        "RefreshPreparedDataJob",
        "PruneAnonymousJourneysJob"
      )
    end
  end
end
