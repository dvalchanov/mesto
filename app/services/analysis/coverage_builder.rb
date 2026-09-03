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
      { "status" => level, "succeeded" => succeeded, "checked" => checked }
    end

    private

    def relevant_runs
      return @source_runs unless @analysis && !@analysis.centroid

      @source_runs.where.not(
        "source_key LIKE ? OR source_key LIKE ? OR source_key LIKE ?",
        "sofiaplan_dataset_%", "arcgis_%", "openstreetmap_%"
      )
    end
  end
end
