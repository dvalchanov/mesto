require "rails_helper"

RSpec.describe RequestThrottle do
  describe ".allowed?" do
    it "uses the shared Rails cache in production" do
      cache = instance_double(ActiveSupport::Cache::Store)
      allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))
      allow(Rails).to receive(:cache).and_return(cache)
      allow(cache).to receive(:increment).and_return(1)

      expect(described_class.allowed?("property-analysis/test", limit: 2, period: 1.minute)).to be(true)
      expect(cache).to have_received(:increment).with(
        start_with("throttle/property-analysis/test/"),
        1,
        expires_in: 61.seconds
      )
    end

    it "fails closed when the shared cache cannot increment the counter" do
      cache = instance_double(ActiveSupport::Cache::Store, increment: nil)
      allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))
      allow(Rails).to receive(:cache).and_return(cache)

      expect(described_class.allowed?("property-analysis/test", limit: 2, period: 1.minute)).to be(false)
    end
  end
end
