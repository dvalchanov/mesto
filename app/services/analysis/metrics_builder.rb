module Analysis
  class MetricsBuilder
    RADII = [ 500, 1_000, 2_000 ].freeze
    AMENITY_CATEGORIES = %w[schools kindergartens green_spaces transit].freeze

    def initialize(analysis:)
      @analysis = analysis
    end

    def call
      metrics = {
        "direct_activity" => direct_activity,
        "nearby_activity" => nearby_activity,
        "amenities" => cached_amenities,
        "environment" => cached_environment,
        "freshness" => freshness
      }
      metrics["development_pressure"] = development_pressure(metrics.fetch("nearby_activity"))
      metrics
    end

    def development_pressure(nearby)
      return { "level" => "unavailable", "reason" => nearby["reason"] } unless nearby["available"]

      { "level" => "unavailable", "reason" => "identifier_search_only" }
    end

    private

    def cached_amenities
      SharedSpatialCalculationCache.new(
        analysis: @analysis,
        calculation_kind: "amenities",
        subject_key: @analysis.building_identifier || @analysis.parcel_identifier,
        geometry: location_point,
        geometry_basis: @analysis.geometry_bases["amenity_proximity"] || "resolved_location_point"
      ).fetch { amenities }
    end

    def cached_environment
      geometry = @analysis.parcel_geometry || location_point
      SharedSpatialCalculationCache.new(
        analysis: @analysis,
        calculation_kind: "environment",
        subject_key: @analysis.parcel_identifier,
        geometry:,
        geometry_basis: @analysis.parcel_geometry ? "parcel_polygon" : "resolved_location_point"
      ).fetch { environment }
    end

    def direct_activity
      acts = @analysis.administrative_acts
      {
        "total" => acts.count,
        "by_registry" => AdministrativeAct::REGISTRY_KINDS.index_with { |kind| acts.where(registry_kind: kind).count },
        "by_reference" => @analysis.identifiers_for_matching.index_with do |identifier|
          acts.joins(:administrative_act_references)
            .where(administrative_act_references: { cadastral_identifier: identifier }).distinct.count
        end
      }
    end

    def nearby_activity
      return { "available" => false, "reason" => "insufficient_geometry" } unless location_point

      nag_runs = source_runs.where("source_key LIKE ?", "nag_%")
      complete = nag_runs.exists? && nag_runs.where.not(status: "succeeded").none? &&
        nag_runs.all? { |run| run.parsed_payload["coverage_status"] == "complete" }
      return { "available" => false, "reason" => "partial_area_coverage" } unless complete

      radii = [ 100, 250, 500 ]
      {
        "available" => true,
        "coverage_status" => "complete",
        "distance_method" => "straight_line",
        "geometry_basis" => @analysis.geometry_bases["nearby_development"] || "resolved_location_point",
        "counts" => radii.index_with { |radius| AdministrativeAct.near(location_point, radius).count }
          .transform_keys(&:to_s)
      }
    end

    def amenities
      return { "available" => false, "reason" => "insufficient_geometry", "availability" => {} } unless location_point

      current_places_available = current_amenity_source_run&.status == "succeeded" && current_amenity_dataset.present?
      availability = AMENITY_CATEGORIES.index_with do |category|
        if category.in?(%w[schools kindergartens])
          current_places_available || spatial_dataset_available?(category)
        else
          spatial_dataset_available?(category)
        end
      end
      result = {
        "available" => availability.values.all?,
        "availability" => availability,
        "datasets" => AMENITY_CATEGORIES.index_with do |category|
          category.in?(%w[schools kindergartens]) && current_places_available ? current_amenity_metadata : dataset_metadata(category)
        end,
        "places_source" => current_places_available ? "openstreetmap" : "sofiaplan",
        "distance_method" => "straight_line",
        "geometry_basis" => @analysis.geometry_bases["amenity_proximity"] || "resolved_location_point"
      }
      %w[schools kindergartens].each do |category|
        if current_places_available
          nearby = current_amenity_features(category)
          result[category] = RADII.index_with { |radius| nearby.count { |feature| feature.fetch("distance_m") <= radius } }
            .transform_keys(&:to_s)
          result["nearest_#{category.singularize}"] = nearby.first
          result["nearby_#{category}"] = nearby
        elsif availability[category]
          result[category] = RADII
            .index_with { |radius| dataset_for_category(category).spatial_features.within(location_point, radius).count }
            .transform_keys(&:to_s)
        else
          result[category] = {}
        end
        result["nearest_#{category.singularize}"] = nearest(category) if !current_places_available && availability[category]
      end
      result["nearest_green_space"] = nearest("green_spaces", fallback_property: "type_") if availability["green_spaces"]
      if availability["transit"]
        result["nearest_existing_transit"] = nearest("transit", property_filter: { "layer" => "existing" })
        result["nearest_planned_transit"] = nearest("transit", property_filter: { "layer" => "planned" })
      end
      result
    end

    def nearest(category, property_filter: nil, fallback_property: nil)
      dataset = dataset_for_category(category)
      return unless dataset

      relation = dataset.spatial_features.in_category(category)
      property_filter&.each do |key, value|
        relation = relation.where("spatial_features.properties ->> ? = ?", key, value)
      end
      feature = relation.nearest_to(location_point).first
      return unless feature

      {
        "name" => feature.name.presence || feature.properties[fallback_property].presence,
        "distance_m" => feature.distance_to(location_point).round,
        "source_url" => feature.spatial_dataset.source_url
      }
    end

    def current_amenity_source_run
      return @current_amenity_source_run if defined?(@current_amenity_source_run)

      @current_amenity_source_run = source_runs
        .where(source_key: "openstreetmap_nearby_amenities")
        .order(id: :desc).first
    end

    def current_amenity_features(category)
      return [] unless current_amenity_dataset

      current_amenity_dataset.spatial_features.in_category(category)
        .within(location_point, DataSources::OpenStreetMap::NearbyAmenitiesClient::RADIUS_METRES)
        .nearest_to(location_point)
        .with_distance_to(location_point)
        .map do |feature|
          {
            "category" => category,
            "name" => feature.name,
            "address" => feature.address,
            "operator" => feature.properties["operator"],
            "distance_m" => feature[:map_distance_m].to_f.round,
            "source_url" => feature.properties["source_url"] || current_amenity_dataset.source_url
          }.compact
        end
    end

    def current_amenity_metadata
      run = current_amenity_source_run
      dataset = current_amenity_dataset
      {
        "provider" => "OpenStreetMap",
        "relevant_at" => dataset&.relevant_at&.to_date&.iso8601,
        "retrieved_at" => dataset&.last_imported_at&.iso8601,
        "source_url" => dataset&.permission_reference || run.source_url
      }.compact
    end

    def current_amenity_dataset
      return @current_amenity_dataset if defined?(@current_amenity_dataset)

      key = DataSources.config.dig("openstreetmap", "dataset_key")
      @current_amenity_dataset = SpatialDataset.usable.find_by(
        key:,
        coverage_profile_key: @analysis.coverage_profile_key
      )
    end

    def environment
      geometry = @analysis.parcel_geometry || location_point
      return { "available" => false, "reason" => "insufficient_geometry" } unless geometry
      return { "available" => false, "reason" => "source_unavailable" } unless spatial_dataset_available?("flood_risk")

      {
        "available" => true,
        "geometry_basis" => @analysis.parcel_geometry ? "parcel" : "point",
        "flood_risk_intersections" => dataset_for_category("flood_risk").spatial_features.intersecting(geometry).count,
        "dataset" => dataset_metadata("flood_risk")
      }
    end

    def spatial_dataset_available?(category)
      latest_source_status("sofiaplan_dataset_#{category}") == "succeeded" &&
        dataset_for_category(category).present?
    end

    def latest_source_status(source_key)
      source_runs.where(source_key:).order(id: :desc).pick(:status)
    end

    def dataset_metadata(category)
      dataset = dataset_for_category(category)
      return {} unless dataset&.last_imported_at

      {
        "relevant_at" => dataset.relevant_at&.to_date&.iso8601,
        "source_url" => dataset.source_url
      }.compact
    end

    def freshness
      dated = source_runs.where.not(relevant_at: nil)
      {
        "newest_checked_at" => source_runs.maximum(:fetched_at)&.iso8601,
        "oldest_relevant_at" => dated.minimum(:relevant_at)&.to_date&.iso8601,
        "unknown_relevance_count" => source_runs.where(relevant_at: nil).count
      }
    end


    def location_point
      @analysis.location_point
    end

    def source_runs
      @analysis.current_source_runs
    end

    def dataset_for_category(category)
      SpatialDataset.usable.find_by(
        key: category,
        coverage_profile_key: @analysis.coverage_profile_key
      )
    end
  end
end
