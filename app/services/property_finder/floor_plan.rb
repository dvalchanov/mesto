module PropertyFinder
  class FloorPlan
    def initialize(building_identifier:, properties:)
      @building_identifier = building_identifier
      @properties = Array(properties)
    end

    def call
      {
        type: "FeatureCollection",
        features: [ building_feature, *@properties.filter_map { |property| unit_feature(property) } ].compact
      }
    end

    private

    def building_feature
      building = CadastralProperty.usable.find_by(
        identifier_level: "building",
        cadastral_identifier: @building_identifier
      )
      return unless building&.geometry

      {
        type: "Feature",
        geometry: RGeo::GeoJSON.encode(building.geometry),
        properties: { kind: "building", identifier: building.cadastral_identifier }
      }
    end

    def unit_feature(property)
      return unless property.geometry
      return unless property.cadastral_identifier.start_with?("#{@building_identifier}.")

      {
        type: "Feature",
        id: property.cadastral_identifier,
        geometry: RGeo::GeoJSON.encode(property.geometry),
        properties: {
          kind: "unit",
          identifier: property.cadastral_identifier,
          object_number: property.object_number,
          entrance: property.entrance,
          floor: property.floor,
          area_sqm: property.area_sqm&.to_f
        }.compact
      }
    end
  end
end
