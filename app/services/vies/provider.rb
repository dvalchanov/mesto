module Vies
  class Provider
    def self.configured
      return UnavailableProvider.new if DataSources.fixture?

      LiveProvider.new(config: DataSources.config.fetch("vies"))
    end

    def lookup(eik:)
      raise NotImplementedError
    end
  end
end
