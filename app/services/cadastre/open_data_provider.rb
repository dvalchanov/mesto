module Cadastre
  class OpenDataProvider < Provider
    def initialize(config:, coverage_profile: DataCoverage.profile)
      @config = config
      @coverage_profile = coverage_profile
    end

    def locate(identifier:, hints: {})
      parsed_identifier = CadastralIdentifier.new(identifier)
      properties = hierarchy_properties(parsed_identifier)
      property = properties[parsed_identifier.level.to_s]
      coverage_property = [ property, properties["building"], properties["parcel"] ].compact.find(&:geometry)
      return outside_coverage(identifier) if coverage_property && !@coverage_profile.covers_property?(coverage_property)
      return unavailable(identifier) unless property

      DataSources::Result.success(
        data: payload(property, properties), source_url: property.source_url,
        fetched_at: property.updated_at, relevant_at: property.source_relevant_at
      )
    rescue StandardError => error
      DataSources::Result.unavailable(source_url: @config.fetch("portal_url"), error:)
    end

    private

    def unavailable(identifier)
      DataSources::Result.unavailable(
        source_url: @config.fetch("portal_url"),
        error: DataCoverage::DatasetNotPrepared.new(
          "The prepared #{@coverage_profile.label} cadastral dataset has no exact record for #{identifier}"
        )
      )
    end

    def outside_coverage(identifier)
      DataSources::Result.unavailable(
        source_url: @config.fetch("portal_url"),
        error: DataCoverage::OutsideSearchCoverage.new(
          "#{identifier} is outside the #{@coverage_profile.label} search dataset"
        )
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

    def payload(property, properties)
      result = PropertyPayload.call(property).merge("subject_area_sqm" => property.area_sqm&.to_f)
      result["cadastre_records"] = properties.transform_values { |record| PropertyPayload.call(record) }

      parcel = properties["parcel"]
      building = properties["building"]
      result["subject_geometry"] = property.geometry if property.geometry
      result["building_geometry"] = building.geometry if building&.geometry
      result["parcel_geometry"] = parcel.geometry if parcel&.geometry
      result["geometry"] = parcel.geometry if parcel&.geometry # Backwards-compatible report evidence.

      focus_record, focus_basis = if building&.geometry
        [ building, "selected_building_representative_point" ]
      elsif property.geometry
        [ property, "selected_subject_representative_point" ]
      elsif parcel&.geometry
        [ parcel, "parcel_representative_point" ]
      end
      if focus_record
        point = CadastralProperty.where(id: focus_record.id).pick(Arel.sql("ST_PointOnSurface(geometry)"))
        result["analysis_point"] = point
        result["centroid"] = point # Legacy field consumed by existing reports.
        result["precision"] = "cadastral_geometry"
        result["geometry_bases"] = {
          "selected_property_display" => property.geometry ? "subject_cadastral_outline" : "unavailable",
          "location_focus" => focus_basis,
          "amenity_proximity" => focus_basis,
          "parcel_planning" => parcel&.geometry ? "parcel_polygon" : "unavailable",
          "adjacent_parcels" => parcel&.geometry ? "parcel_geometries" : "unavailable",
          "nearby_development" => focus_basis
        }
      end
      result.compact
    end
  end
end
