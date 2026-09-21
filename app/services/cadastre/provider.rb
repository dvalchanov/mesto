module Cadastre
  class Provider
    def self.configured
      config = DataSources.config.fetch("cadastre")
      case config.fetch("provider")
      when "open_data"
        open_data_config = config.fetch("open_data")
        approved = !Rails.env.production? || CadastreSourceArchive.for_profile(DataCoverage.profile)
          .where(object_kind: CadastralProperty::ARCHIVE_OBJECT_KINDS, permission_status: "approved")
          .exists?
        if approved
          OpenDataProvider.new(config: open_data_config)
        else
          NullProvider.new
        end
      else NullProvider.new
      end
    end

    def locate(identifier:, hints: {})
      raise NotImplementedError
    end
  end
end
