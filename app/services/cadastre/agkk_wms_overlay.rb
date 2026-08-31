module Cadastre
  class AgkkWmsOverlay < Provider
    def initialize(config:)
      @config = config
    end

    def locate(identifier:, hints: {})
      error = if @config["wms_url"].blank?
        "AGKK WMS URL is not configured"
      else
        "Configured WMS is a rendered overlay and cannot provide authoritative vector geometry"
      end
      DataSources::Result.unavailable(source_url: @config["wms_url"].presence || "https://kais.cadastre.bg", error: StandardError.new(error))
    end

    def overlay_url = @config["wms_url"].presence
  end
end
