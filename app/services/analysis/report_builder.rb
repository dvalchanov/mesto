module Analysis
  class ReportBuilder
    def initialize(analysis:, metrics:, coverage:)
      @analysis = analysis
      @metrics = metrics
      @coverage = coverage
    end

    def call
      planning = planning_features
      paid_content = @coverage["status"] == "complete" && meaningful_paid_sections?(planning)
      {
        "progress" => @analysis.progress,
        "coverage" => @coverage,
        "property_facts" => property_facts,
        "signals" => signals.first(2),
        "questions" => QuestionsBuilder.new(analysis: @analysis, metrics: @metrics).call,
        "planning" => planning,
        "planning_summary" => PlanningSummaryBuilder.new(planning).call,
        "paid_content_available" => paid_content,
        "generated_at" => Time.current.iso8601
      }
    end

    private

    def property_facts
      PropertyFactsBuilder.new(analysis: @analysis).call
    end

    def signals
      result = []
      total = @metrics.dig("direct_activity", "total").to_i
      result << { "key" => "acts_found", "count" => total } if total.positive?
      permit = @analysis.administrative_acts.where(registry_kind: "building_permits").where.not(issued_on: nil).order(issued_on: :desc).first
      result << { "key" => "building_permit", "year" => permit.issued_on.year } if permit
      result << { "key" => "design_visa" } if @analysis.administrative_acts.where(registry_kind: "design_visas").exists?
      result << { "key" => "location_unavailable" } unless @analysis.centroid
      result << { "key" => "no_matches" } if total.zero? && @analysis.source_runs.succeeded.exists?
      result
    end

    def planning_features
      @analysis.source_runs.where(source_key: %w[arcgis_development_potential arcgis_functional_zoning])
        .where(status: "succeeded").map do |run|
          { "source_key" => run.source_key, "features" => run.parsed_payload.fetch("features", []) }
        end
    end

    def meaningful_paid_sections?(planning)
      @analysis.administrative_acts.exists? ||
        planning.any? { |layer| Array(layer["features"]).any? } ||
        @metrics.dig("amenities", "availability")&.value?(true) ||
        @metrics.dig("environment", "available") == true
    end
  end
end
