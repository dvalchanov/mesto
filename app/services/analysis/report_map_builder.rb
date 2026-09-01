module Analysis
  class ReportMapBuilder
    BUILDING_RADIUS_METRES = 175
    AMENITY_RADIUS_METRES = 1_000
    MAX_NEARBY_BUILDINGS = 40
    AMENITY_CATEGORIES = %w[schools kindergartens green_spaces transit flood_risk].freeze
    MAX_FEATURES_BY_CATEGORY = {
      "schools" => 20,
      "kindergartens" => 20,
      "green_spaces" => 10,
      "transit" => 10,
      "flood_risk" => 5
    }.freeze

    def initialize(analysis:, acts: AdministrativeAct.none)
      @analysis = analysis
      @acts = acts
    end

    def call
      features = []
      add_cadastral_context(features)
      add_administrative_acts(features)
      add_spatial_context(features)
      add_planning(features)

      { type: "FeatureCollection", features: }
    end

    private

    def add_cadastral_context(features)
      records = hierarchy_records
      add_record(features, records["parcel"], "parcel", fallback_geometry: @analysis.parcel_geometry)
      add_record(features, records["building"], "selected_building")
      add_record(features, records["individual_object"], "selected_object")

      nearby_buildings.each do |building|
        add_record(features, building, "nearby_building")
      end

      return unless @analysis.centroid

      features << map_feature(
        @analysis.centroid,
        kind: "selected_location",
        label: @analysis.submitted_identifier,
        type_label: translate_feature_type("selected_location"),
        focus: true
      )
    end

    def hierarchy_records
      @hierarchy_records ||= begin
        identifiers = {
          "parcel" => @analysis.parcel_identifier,
          "building" => @analysis.building_identifier,
          "individual_object" => @analysis.individual_object_identifier
        }.compact
        records = CadastralProperty.where(cadastral_identifier: identifiers.values)
          .index_by(&:cadastral_identifier)
        identifiers.transform_values { |identifier| records[identifier] }.compact
      end
    end

    def nearby_buildings
      return CadastralProperty.none unless @analysis.centroid

      relation = CadastralProperty.where(identifier_level: "building")
        .where.not(geometry: nil)
        .near(@analysis.centroid, BUILDING_RADIUS_METRES)
        .nearest_to(@analysis.centroid)
      relation = relation.where.not(cadastral_identifier: @analysis.building_identifier) if @analysis.building_identifier
      relation.limit(MAX_NEARBY_BUILDINGS)
    end

    def add_record(features, record, kind, fallback_geometry: nil)
      geometry = record&.geometry || fallback_geometry
      return unless geometry

      identifier = record&.cadastral_identifier || @analysis.parcel_identifier
      features << map_feature(
        geometry,
        kind:,
        label: identifier,
        type_label: translate_feature_type(kind),
        detail: record_detail(record),
        address: record&.address,
        source_url: record&.source_url,
        date_label: date_label(record&.source_relevant_at),
        focus: true
      )
    end

    def record_detail(record)
      return unless record

      details = []
      details << record.purpose
      details << I18n.t("reports.map.popup.floors", count: record.floors_count) if record.floors_count
      details.compact_blank.join(" · ").presence
    end

    def add_administrative_acts(features)
      @acts.where.not(geometry: nil).limit(100).each do |act|
        features << map_feature(
          act.geometry,
          kind: "act",
          label: act.title.presence || act.act_number,
          type_label: translate_feature_type("act"),
          date_label: issued_label(act.issued_on),
          address: act.address,
          source_url: act.source_url
        )
      end
    end

    def add_spatial_context(features)
      return unless @analysis.centroid

      AMENITY_CATEGORIES.each do |category|
        next unless spatial_dataset_available?(category)

        SpatialFeature.in_category(category)
          .within(@analysis.centroid, AMENITY_RADIUS_METRES)
          .nearest_to(@analysis.centroid)
          .with_distance_to(@analysis.centroid)
          .includes(:spatial_dataset)
          .limit(MAX_FEATURES_BY_CATEGORY.fetch(category))
          .each do |feature|
            features << map_feature(
              feature.geometry,
              kind: "amenity",
              category:,
              label: feature.name,
              type_label: spatial_feature_type(feature, category),
              address: feature.address,
              source_url: feature.spatial_dataset.source_url,
              date_label: date_label(feature.spatial_dataset.relevant_at),
              distance_label: distance_label(feature[:map_distance_m])
            )
          end
      end
    end

    def spatial_dataset_available?(category)
      @analysis.source_runs.where(source_key: "sofiaplan_dataset_#{category}")
        .order(id: :desc).pick(:status) == "succeeded"
    end

    def spatial_feature_type(feature, category)
      return translate_feature_type(category) unless category == "transit"

      layer = feature.properties["layer"]
      translate_feature_type(layer == "planned" ? "planned_transit" : "existing_transit")
    end

    def add_planning(features)
      Array(@analysis.summary["planning"]).each do |layer|
        Array(layer["features"]).each do |feature|
          features << feature.deep_dup.tap do |entry|
            entry["properties"] = entry.fetch("properties", {}).merge(
              "kind" => "planning",
              "source_key" => layer["source_key"],
              "type_label" => translate_feature_type("planning"),
              "label" => I18n.t("reports.sources.names.#{layer['source_key']}"),
              "source_url" => planning_source_urls[layer["source_key"]]
            )
          end
        end
      end
    end

    def planning_source_urls
      @planning_source_urls ||= @analysis.source_runs
        .where(source_key: %w[arcgis_development_potential arcgis_functional_zoning])
        .where.not(source_url: nil)
        .pluck(:source_key, :source_url)
        .to_h
    end

    def map_feature(geometry, properties)
      {
        type: "Feature",
        geometry: RGeo::GeoJSON.encode(geometry),
        properties: properties.compact
      }
    end

    def translate_feature_type(key)
      I18n.t("reports.map.feature_types.#{key}")
    end

    def date_label(value)
      return unless value

      I18n.t("reports.map.popup.data_date", date: I18n.l(value.to_date, format: :short))
    end

    def issued_label(value)
      return unless value

      I18n.t("reports.map.popup.issued_on", date: I18n.l(value, format: :short))
    end

    def distance_label(value)
      return unless value

      I18n.t("reports.map.popup.distance", distance: value.to_f.round)
    end
  end
end
