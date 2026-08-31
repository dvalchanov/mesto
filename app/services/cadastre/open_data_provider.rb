module Cadastre
  class OpenDataProvider < Provider
    def initialize(config:)
      @config = config
    end

    def locate(identifier:, hints: {})
      parsed_identifier = CadastralIdentifier.new(identifier)
      properties = hierarchy_properties(parsed_identifier)
      if auto_import? && hierarchy_incomplete?(properties, parsed_identifier)
        import_hierarchy(parsed_identifier, hints[:district])
        properties = hierarchy_properties(parsed_identifier)
      end
      property = properties[parsed_identifier.level.to_s]
      return unavailable(identifier) unless property

      DataSources::Result.success(
        data: payload(property, properties), source_url: property.source_url,
        fetched_at: property.updated_at, relevant_at: property.source_relevant_at
      )
    rescue StandardError => error
      DataSources::Result.unavailable(source_url: @config.fetch("portal_url"), error:)
    end

    private

    def import_hierarchy(identifier, district)
      return if DataSources.fixture? || district.blank?

      DataSources::CadastreOpenData::DistrictSynchronizer.new
        .sync_sofia_property_hierarchy(district, identifier_level: identifier.level.to_s)
    end

    def auto_import?
      ActiveModel::Type::Boolean.new.cast(@config.fetch("auto_import", false))
    end

    def unavailable(identifier)
      DataSources::Result.unavailable(
        source_url: @config.fetch("portal_url"),
        error: StandardError.new("No imported AGKK open-data record was found for #{identifier}")
      )
    end

    def hierarchy_properties(identifier)
      identifiers = {
        "parcel" => identifier.parcel_identifier,
        "building" => identifier.building_identifier,
        "individual_object" => identifier.individual_object_identifier
      }.compact
      records = CadastralProperty.where(cadastral_identifier: identifiers.values)
        .index_by(&:cadastral_identifier)
      identifiers.transform_values { |value| records[value] }.compact
    end

    def hierarchy_incomplete?(properties, identifier)
      expected = DataSources::CadastreOpenData::DistrictSynchronizer::HIERARCHY_ARCHIVES
        .fetch(identifier.level.to_s)
      expected.length != properties.length
    end

    def payload(property, properties)
      result = PropertyPayload.call(property).merge("subject_area_sqm" => property.area_sqm&.to_f)
      result["cadastre_records"] = properties.transform_values { |record| PropertyPayload.call(record) }

      parcel = properties["parcel"]
      if parcel&.geometry
        result["geometry"] = parcel.geometry
        result["centroid"] = CadastralProperty.where(id: parcel.id).pick(Arel.sql("ST_Centroid(geometry)"))
        result["precision"] = "cadastral_geometry"
      end
      result.compact
    end
  end
end
