require "rails_helper"

RSpec.describe Mesto::SidekiqWebAuthentication do
  describe ".valid?" do
    let(:env) do
      {
        "SIDEKIQ_WEB_USERNAME" => "operator",
        "SIDEKIQ_WEB_PASSWORD" => "a-long-unique-password"
      }
    end

    it "accepts the configured credentials" do
      expect(described_class.valid?("operator", "a-long-unique-password", env:)).to be(true)
    end

    it "rejects an incorrect username" do
      expect(described_class.valid?("someone-else", "a-long-unique-password", env:)).to be(false)
    end

    it "rejects an incorrect password" do
      expect(described_class.valid?("operator", "wrong-password", env:)).to be(false)
    end

    it "fails closed when either credential is missing" do
      expect(described_class.valid?("", "", env: {})).to be(false)
      expect(described_class.valid?("operator", "", env: env.except("SIDEKIQ_WEB_PASSWORD"))).to be(false)
      expect(described_class.valid?("", "a-long-unique-password", env: env.except("SIDEKIQ_WEB_USERNAME"))).to be(false)
    end
  end
end
