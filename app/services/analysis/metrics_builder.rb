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
        "amenities" => amenities,
        "environment" => environment,
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
      # NAG is queried by the submitted cadastral identifiers. The records in our
      # database are therefore not a complete area-wide register and cannot
      # support defensible radius counts or a development-pressure score.
      { "available" => false, "reason" => "identifier_search_only" }
    end

    def amenities
      return { "available" => false, "reason" => "insufficient_geometry", "availability" => {} } unless @analysis.centroid

      availability = AMENITY_CATEGORIES.index_with { |category| spatial_dataset_available?(category) }
      result = {
        "available" => availability.values.all?,
        "availability" => availability,
        "datasets" => AMENITY_CATEGORIES.index_with { |category| dataset_metadata(category) }
      }
      %w[schools kindergartens].each do |category|
        result[category] = if availability[category]
          RADII.index_with { |radius| SpatialFeature.in_category(category).within(@analysis.centroid, radius).count }
            .transform_keys(&:to_s)
        else
          {}
        end
        result["nearest_#{category.singularize}"] = nearest(category) if availability[category]
      end
      result["nearest_green_space"] = nearest("green_spaces", fallback_property: "type_") if availability["green_spaces"]
      if availability["transit"]
        result["nearest_existing_transit"] = nearest("transit", property_filter: { "layer" => "existing" })
        result["nearest_planned_transit"] = nearest("transit", property_filter: { "layer" => "planned" })
      end
      result
    end

    def nearest(category, property_filter: nil, fallback_property: nil)
      relation = SpatialFeature.in_category(category)
      property_filter&.each do |key, value|
        relation = relation.where("spatial_features.properties ->> ? = ?", key, value)
      end
      feature = relation.nearest_to(@analysis.centroid).first
      return unless feature

      {
        "name" => feature.name.presence || feature.properties[fallback_property].presence,
        "distance_m" => feature.distance_to(@analysis.centroid).round,
        "source_url" => feature.spatial_dataset.source_url
      }
    end

    def environment
      geometry = @analysis.parcel_geometry || @analysis.centroid
      return { "available" => false, "reason" => "insufficient_geometry" } unless geometry
      return { "available" => false, "reason" => "source_unavailable" } unless spatial_dataset_available?("flood_risk")

      {
        "available" => true,
        "geometry_basis" => @analysis.parcel_geometry ? "parcel" : "point",
        "flood_risk_intersections" => SpatialFeature.in_category("flood_risk").intersecting(geometry).count,
        "dataset" => dataset_metadata("flood_risk")
      }
    end

    def spatial_dataset_available?(category)
      latest_source_status("sofiaplan_dataset_#{category}") == "succeeded" &&
        SpatialDataset.where(key: category).where.not(last_imported_at: nil).exists?
    end

    def latest_source_status(source_key)
      @analysis.source_runs.where(source_key:).order(id: :desc).pick(:status)
    end

    def dataset_metadata(category)
      dataset = SpatialDataset.find_by(key: category)
      return {} unless dataset&.last_imported_at

      {
        "relevant_at" => dataset.relevant_at&.to_date&.iso8601,
        "source_url" => dataset.source_url
      }.compact
    end

    def freshness
      dated = @analysis.source_runs.where.not(relevant_at: nil)
      {
        "newest_checked_at" => @analysis.source_runs.maximum(:fetched_at)&.iso8601,
        "oldest_relevant_at" => dated.minimum(:relevant_at)&.to_date&.iso8601,
        "unknown_relevance_count" => @analysis.source_runs.where(relevant_at: nil).count
      }
    end
  end
end
