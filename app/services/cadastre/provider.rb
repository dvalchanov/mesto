module Cadastre
  class Provider
    def self.configured
      config = DataSources.config.fetch("cadastre")
      case config.fetch("provider")
      when "open_data" then OpenDataProvider.new(config: config.fetch("open_data"))
      else NullProvider.new
      end
    end

    def locate(identifier:, hints: {})
      raise NotImplementedError
    end
  end
end
