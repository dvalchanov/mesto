module PropertyRegistry
  class Provider
    def self.configured
      config = DataSources.config.fetch("property_register")
      case config.fetch("provider")
      when "unavailable"
        UnavailableProvider.new(config:)
      when "demo"
        DemoProvider.new(config:)
      else
        raise ArgumentError, "Unsupported Property Register provider: #{config.fetch('provider')}"
      end
    end

    def lookup(cadastral_identifier:)
      raise NotImplementedError
    end
  end
end
