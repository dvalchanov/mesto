require "rails_helper"

RSpec.describe Mesto::RedisConnection do
  describe ".options" do
    it "uses certificate verification for ordinary TLS Redis providers" do
      expect(described_class.options(url: "rediss://cache.example.com:6380", ssl_verify_mode: "peer")).to eq(
        url: "rediss://cache.example.com:6380",
        ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_PEER }
      )
    end

    it "supports Heroku KVS self-signed certificates when explicitly configured" do
      expect(described_class.options(url: "rediss://cache.example.com:6380", ssl_verify_mode: "none")).to eq(
        url: "rediss://cache.example.com:6380",
        ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
      )
    end

    it "does not add TLS options to a plain Redis connection" do
      expect(described_class.options(url: "redis://localhost:6379/0", ssl_verify_mode: "peer")).to eq(
        url: "redis://localhost:6379/0"
      )
    end

    it "rejects an unknown TLS verification mode" do
      expect {
        described_class.options(url: "rediss://cache.example.com:6380", ssl_verify_mode: "sometimes")
      }.to raise_error(ArgumentError, "REDIS_SSL_VERIFY_MODE must be 'peer' or 'none'")
    end
  end
end
