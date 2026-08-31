module Analysis
  class MetricsBuilder
    RADII = [ 500, 1_000, 2_000 ].freeze
    ACTIVITY_RADII = [ 100, 250, 500 ].freeze

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
      return { "level" => "unavailable", "reason" => "insufficient_geometry" } unless nearby["available"]

      recent = nearby.fetch("recent_counts", {})
      within_100 = recent.fetch("100", 0)
      within_250 = recent.fetch("250", 0)
      within_500 = recent.fetch("500", 0)
      level = if within_100 >= 2 || within_250 >= 5
        "high"
      elsif within_100 >= 1 || within_500 >= 3
        "medium"
      else
        "low"
      end
      { "level" => level, "within_100" => within_100, "within_250" => within_250, "within_500" => within_500 }
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
      return { "available" => false } unless @analysis.centroid

      cutoff = Rails.application.config.x.development_pressure_years.years.ago.to_date
      counts = ACTIVITY_RADII.index_with { |radius| AdministrativeAct.near(@analysis.centroid, radius).count }
      recent = ACTIVITY_RADII.index_with do |radius|
        AdministrativeAct.near(@analysis.centroid, radius).where(issued_on: cutoff..).count
      end
      nearby = AdministrativeAct.near(@analysis.centroid, ACTIVITY_RADII.max)
      {
        "available" => true,
        "radius_based" => @analysis.parcel_geometry.nil?,
        "counts" => counts.transform_keys(&:to_s),
        "recent_counts" => recent.transform_keys(&:to_s),
        "by_registry" => AdministrativeAct::REGISTRY_KINDS.index_with { |kind| nearby.where(registry_kind: kind).count },
        "most_recent_on" => nearby.maximum(:issued_on)&.iso8601
      }
    end

    def amenities
      return { "available" => false } unless @analysis.centroid

      %w[schools kindergartens].index_with do |category|
        RADII.index_with { |radius| SpatialFeature.in_category(category).within(@analysis.centroid, radius).count }
          .transform_keys(&:to_s)
      end.merge(
        "available" => true,
        "nearest_green_space" => nearest("green_spaces"),
        "nearest_transit" => nearest("transit")
      )
    end

    def nearest(category)
      feature = SpatialFeature.in_category(category).nearest_to(@analysis.centroid).first
      return unless feature

      { "name" => feature.name, "distance_m" => feature.distance_to(@analysis.centroid).round, "source_url" => feature.spatial_dataset.source_url }
    end

    def environment
      geometry = @analysis.parcel_geometry || @analysis.centroid
      return { "available" => false } unless geometry

      { "available" => true, "flood_risk_intersections" => SpatialFeature.in_category("flood_risk").intersecting(geometry).count }
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
