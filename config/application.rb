require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Mesto
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Keep web requests and background work on one conventional Active Job API.
    config.active_job.queue_adapter = :sidekiq

    config.i18n.default_locale = :bg
    config.i18n.available_locales = %i[bg en]
    config.i18n.fallbacks = [ :en ]

    config.x.product_name = ENV.fetch("PRODUCT_NAME", "Mesto")
    config.x.app_host = ENV.fetch("APP_HOST", "mesto.bg")
    config.x.data_source_mode = ENV.fetch("DATA_SOURCE_MODE", Rails.env.test? ? "fixture" : "live")
    config.x.store_raw_source_responses = ActiveModel::Type::Boolean.new.cast(
      ENV.fetch("STORE_RAW_SOURCE_RESPONSES", Rails.env.production? ? "false" : "false")
    )
    config.x.payment_provider = ENV.fetch("PAYMENT_PROVIDER", "fake")
    config.x.fake_payments_enabled = ActiveModel::Type::Boolean.new.cast(
      ENV.fetch("FAKE_PAYMENTS_ENABLED", Rails.env.production? ? "false" : "true")
    )
    config.x.map_style_url = ENV["MAP_STYLE_URL"].presence || "https://tiles.openfreemap.org/styles/liberty"
    config.x.development_pressure_years = ENV.fetch("DEVELOPMENT_PRESSURE_YEARS", 5).to_i

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.generators do |generators|
      generators.test_framework :rspec
      generators.fixture_replacement :factory_bot, dir: "spec/factories"
      generators.system_tests = :rspec
    end
  end
end
