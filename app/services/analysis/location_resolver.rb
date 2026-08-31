module Analysis
  class LocationResolver
    def initialize(analysis:, cadastre_result:, nag_records:)
      @analysis = analysis
      @cadastre_result = cadastre_result
      @nag_records = nag_records
    end

    def call
      cadastral = from_cadastre
      return cadastral if cadastral

      official = @nag_records.filter_map { |record| DataSources::Nag::LocationParser.call(record) }
        .find { |candidate| candidate[:centroid] }
      return official if official

      from_address || { precision: "unavailable" }
    end

    private

    def from_cadastre
      return unless @cadastre_result&.success?
      data = @cadastre_result.data.symbolize_keys
      return unless data[:centroid] || data[:geometry]

      {
        centroid: data[:centroid] || data[:geometry].centroid,
        geometry: data[:geometry],
        precision: data[:precision] || "cadastral_geometry"
      }
    end

    def from_address
      address = @nag_records.filter_map { |record| record["address"].presence }.first
      return unless address

      feature = SpatialFeature.in_category("addresses").where("lower(address) = ?", address.downcase).first
      return unless feature

      { centroid: feature.geometry.centroid, precision: "matched_address", address: }
    end
  end
end
