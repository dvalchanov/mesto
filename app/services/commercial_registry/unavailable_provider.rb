module CommercialRegistry
  class UnavailableProvider < Provider
    def initialize(config: DataSources.config.fetch("commercial_register"))
      @config = config
    end

    def lookup_company(eik:)
      DataSources::Result.unavailable(
        source_url: @config.fetch("source_url"),
        error: PublicRegistry::AutomationUnavailable.new(
          "Commercial Register automated access requires a paid contract and an approved technical interface"
        )
      )
    end
  end
end
