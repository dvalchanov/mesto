require "digest"
require "rack/utils"

module Mesto
  class SidekiqWebAuthentication
    def self.valid?(username, password, env: ENV)
      expected_username = env["SIDEKIQ_WEB_USERNAME"].to_s
      expected_password = env["SIDEKIQ_WEB_PASSWORD"].to_s

      return false if expected_username.empty? || expected_password.empty?

      username_matches = secure_compare(username, expected_username)
      password_matches = secure_compare(password, expected_password)

      username_matches & password_matches
    end

    def self.secure_compare(actual, expected)
      Rack::Utils.secure_compare(digest(actual), digest(expected))
    end
    private_class_method :secure_compare

    def self.digest(value)
      Digest::SHA256.hexdigest(value.to_s)
    end
    private_class_method :digest
  end
end
