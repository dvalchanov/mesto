module Analysis
  class CoverageBuilder
    def initialize(source_runs, analysis: nil)
      @source_runs = source_runs
      @analysis = analysis
    end

    def call
      runs = relevant_runs
      checked = runs.where.not(status: %w[pending running]).count
      succeeded = runs.where(status: "succeeded").count
      ratio = checked.zero? ? 0 : succeeded.to_f / checked
      level = if checked.positive? && succeeded == checked
        "complete"
      elsif ratio >= 0.75
        "good"
      elsif succeeded.positive?
        "partial"
      else
        "limited"
      end
      geographic_status = geographic_coverage_status(runs)
      honest_level = if geographic_status != "complete" && level.in?(%w[complete good])
        "partial"
      else
        level
      end
      {
        "status" => honest_level,
        "task_completion_status" => level,
        "geographic_coverage_status" => geographic_status,
        "succeeded" => succeeded,
        "checked" => checked,
        "coverage_profile_key" => @analysis&.coverage_profile_key
      }.compact
    end

    private

    def relevant_runs
      return @source_runs unless @analysis && !@analysis.centroid

      @source_runs.where.not(
        "source_key LIKE ? OR source_key LIKE ? OR source_key LIKE ?",
        "sofiaplan_dataset_%", "arcgis_%", "openstreetmap_%"
      )
    end

    def geographic_coverage_status(runs)
      return "unknown" unless @analysis
      return "outside" if @analysis.analysis_scope_status == "outside"
      return "unknown" unless @analysis.analysis_scope_status == "covered"

      declared = runs.where(status: "succeeded").filter_map do |run|
        run.parsed_payload["coverage_status"]
      end
      declared.any? && declared.all? { |status| status == "complete" } ? "complete" : "partial"
    end
  end
end
