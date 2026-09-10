module Vies
  class UnavailableProvider < Provider
    def lookup(eik:)
      DataSources::Result.unavailable(
        source_url: DataSources.config.dig("vies", "service_url"),
        error: DataCoverage::DatasetNotPrepared.new("VIES is not contacted in fixture mode")
      )
    end
  end
end
