module Analysis
  class PropertyFactsBuilder
    SUBJECT_AREA_KEYS = %w[subject_area_sqm object_area_sqm property_area_sqm area_sqm].freeze
    PARCEL_AREA_KEYS = %w[parcel_area_sqm].freeze

    def initialize(analysis:)
      @analysis = analysis
      @identifier = CadastralIdentifier.new(analysis.submitted_identifier)
      @acts = analysis.administrative_acts.chronological.to_a
    end

    def call
      {
        "property_type" => @analysis.identifier_level,
        "settlement_code" => @analysis.settlement_code,
        "cadastre_area_code" => @identifier.cadastre_area,
        "parcel_number" => @identifier.parcel_number,
        "parcel_identifier" => @analysis.parcel_identifier,
        "building_identifier" => @analysis.building_identifier,
        "individual_object_identifier" => @analysis.individual_object_identifier,
        "subject_area_sqm" => subject_area,
        "subject_area_source" => subject_area_source,
        "parcel_area_sqm" => parcel_area,
        "parcel_area_source" => parcel_area_source,
        "address" => cadastre_value("address") || first_act_value(:address),
        "address_source" => cadastre_value("address").present? ? "cadastre" : "administrative_act",
        "district" => cadastre_value("district") || first_act_value(:district),
        "locality" => cadastre_value("locality") || first_act_value(:stated_locality),
        "upi" => cadastre_value("upi") || first_act_value(:stated_upi),
        "object_number" => cadastre_value("object_number"),
        "floor" => cadastre_value("floor"),
        "levels_count" => numeric_cadastre_value("levels_count")&.to_i,
        "entrance" => cadastre_value("entrance"),
        "purpose" => cadastre_value("purpose"),
        "additional_parts" => cadastre_value("additional_parts"),
        "validation_document" => cadastre_value("validation_document"),
        "cadastre_relevant_at" => cadastre_relevant_at,
        "cadastre_records" => cadastral_records,
        "cadastre_hierarchy_metrics" => cadastral_hierarchy_metrics,
        "location_precision" => @analysis.location_precision,
        "direct_acts_count" => @acts.length,
        "latest_act_on" => @acts.filter_map(&:issued_on).max&.iso8601
      }
    end

    private

    def subject_area
      return parcel_area if @analysis.identifier_level == "parcel"

      numeric_cadastre_value(*SUBJECT_AREA_KEYS)
    end

    def subject_area_source
      return parcel_area_source if @analysis.identifier_level == "parcel" && parcel_area
      "cadastre" if numeric_cadastre_value(*SUBJECT_AREA_KEYS)
    end

    def parcel_area
      numeric_cadastre_value(*PARCEL_AREA_KEYS) || imported_parcel_area || calculated_parcel_area
    end

    def parcel_area_source
      return "cadastre" if numeric_cadastre_value(*PARCEL_AREA_KEYS) || imported_parcel_area
      "geometry_calculation" if calculated_parcel_area
    end

    def imported_parcel_area
      cadastral_properties["parcel"]&.area_sqm&.to_f
    end

    def calculated_parcel_area
      return @calculated_parcel_area if defined?(@calculated_parcel_area)
      return @calculated_parcel_area = nil unless @analysis.persisted? && @analysis.parcel_geometry

      value = PropertyAnalysis.where(id: @analysis.id).pick(
        Arel.sql("ST_Area(parcel_geometry::geography)")
      )
      @calculated_parcel_area = value&.to_f&.round(1)
    end

    def cadastre_payload
      @cadastre_payload ||= begin
        payload = @analysis.source_runs.where(source_key: "cadastre", status: "succeeded")
          .order(created_at: :desc).pick(:parsed_payload)
        payload.presence || local_cadastre_payload
      end
    end

    def local_cadastre_payload
      property = cadastral_properties[@analysis.identifier_level]
      return {} unless property

      Cadastre::PropertyPayload.call(property).merge("subject_area_sqm" => property.area_sqm)
    end

    def cadastre_relevant_at
      run_date = @analysis.source_runs.where(source_key: "cadastre", status: "succeeded")
        .order(created_at: :desc).pick(:relevant_at)
      run_date || cadastral_properties[@analysis.identifier_level]&.source_relevant_at
    end

    def cadastral_records
      cadastral_properties.transform_values { |property| Cadastre::PropertyPayload.call(property) }
    end

    def cadastral_hierarchy_metrics
      Cadastre::HierarchyMetricsBuilder.new(analysis: @analysis, properties: cadastral_properties).call
    end

    def cadastral_properties
      @cadastral_properties ||= begin
        identifiers = {
          "parcel" => @analysis.parcel_identifier,
          "building" => @analysis.building_identifier,
          "individual_object" => @analysis.individual_object_identifier
        }.compact
        records = CadastralProperty.where(cadastral_identifier: identifiers.values)
          .index_by(&:cadastral_identifier)
        identifiers.transform_values { |value| records[value] }.compact
      end
    end

    def cadastre_value(*keys)
      values = flattened_payload(cadastre_payload)
      keys.lazy.map { |key| values[key.to_s] }.find(&:present?)
    end

    def numeric_cadastre_value(*keys)
      value = cadastre_value(*keys)
      return if value.blank?

      Float(value.to_s.tr(",", "."), exception: false)&.round(2)
    end

    def flattened_payload(value, result = {})
      case value
      when Hash
        value.each do |key, child|
          result[key.to_s.underscore] ||= child unless child.is_a?(Hash) || child.is_a?(Array)
          flattened_payload(child, result)
        end
      when Array
        value.each { |child| flattened_payload(child, result) }
      end
      result
    end

    def first_act_value(attribute)
      @acts.lazy.map { |act| act.public_send(attribute) }.find(&:present?)
    end
  end
end
