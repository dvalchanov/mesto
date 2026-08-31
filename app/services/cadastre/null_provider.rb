module Cadastre
  class NullProvider < Provider
    def locate(identifier:, hints: {})
      DataSources::Result.unavailable(
        source_url: "https://kais.cadastre.bg",
        error: StandardError.new("No authorized cadastral vector provider is configured")
      )
    end
  end
end
