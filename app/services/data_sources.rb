module DataSources
  class << self
    def config
      @config ||= Rails.application.config_for(:data_sources).to_h.deep_stringify_keys
    end

    def mode
      Rails.application.config.x.data_source_mode.to_s
    end

    def fixture?
      mode == "fixture"
    end

    def reset_config!
      @config = nil
    end
  end
end
