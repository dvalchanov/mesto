module CommercialRegistry
  class Provider
    def self.configured
      config = DataSources.config.fetch("commercial_register")
      case config.fetch("provider")
      when "unavailable"
        UnavailableProvider.new(config:)
      when "demo"
        DemoProvider.new(config:)
      else
        raise ArgumentError, "Unsupported Commercial Register provider: #{config.fetch('provider')}"
      end
    end

    def lookup_company(eik:)
      raise NotImplementedError
    end
  end
end
