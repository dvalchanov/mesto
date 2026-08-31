module Cadastre
  class PropertyPayload
    FIELDS = %w[
      cadastral_identifier identifier_level area_sqm outline_area_sqm perimeter_m
      settlement_name address district locality street_name street_number place
      object_number floor address_floor levels_count entrance block_number
      purpose purpose_code additional_parts old_identifier ownership_type ownership_code
      objects_count floors_count category_type territory_type territory_code
      permanent_use permanent_use_code quarter regulation_parcel validation_document
      source_archive_key source_url source_relevant_at properties
    ].freeze

    def self.call(property)
      property.attributes.slice(*FIELDS).compact.merge(
        "geometry_available" => property.geometry.present?
      )
    end
  end
end
