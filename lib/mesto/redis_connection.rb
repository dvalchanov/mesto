require "openssl"

module Mesto
  module RedisConnection
    VERIFY_MODES = {
      "peer" => OpenSSL::SSL::VERIFY_PEER,
      "none" => OpenSSL::SSL::VERIFY_NONE
    }.freeze

    def self.options(
      url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
      ssl_verify_mode: ENV.fetch("REDIS_SSL_VERIFY_MODE", "peer")
    )
      options = { url: }
      return options unless url.start_with?("rediss://")

      verify_mode = VERIFY_MODES.fetch(ssl_verify_mode) do
        raise ArgumentError, "REDIS_SSL_VERIFY_MODE must be 'peer' or 'none'"
      end

      options.merge(ssl_params: { verify_mode: })
    end
  end
end
