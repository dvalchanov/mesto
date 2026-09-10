module PropertyRegistry
  class UnavailableProvider < Provider
    def initialize(config: DataSources.config.fetch("property_register"))
      @config = config
    end

    def lookup(cadastral_identifier:)
      DataSources::Result.unavailable(
        source_url: @config.fetch("source_url"),
        error: PublicRegistry::AutomationUnavailable.new(
          "Property Register automated access is not available to Mesto; the official service is restricted to authorized public institutions"
        )
      )
    end
  end
end
