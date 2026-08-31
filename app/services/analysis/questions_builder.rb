module Analysis
  class QuestionsBuilder
    def initialize(analysis:, metrics:)
      @analysis = analysis
      @metrics = metrics
    end

    def call
      questions = []
      kinds = @metrics.dig("direct_activity", "by_registry") || {}
      questions << "reports.questions.building_permit" if kinds.fetch("building_permits", 0).positive?
      questions << "reports.questions.planning_change" if kinds.fetch("urban_planning_orders", 0).positive? || planning_data?
      questions << "reports.questions.freshness" if @analysis.source_runs.where(relevant_at: nil).exists?
      questions << "reports.questions.occupancy" if @analysis.building_identifier.present?
      questions << "reports.questions.encumbrances"
      questions.uniq
    end

    private

    def planning_data?
      @analysis.source_runs.where(source_key: %w[arcgis_development_potential arcgis_functional_zoning])
        .where(status: "succeeded").exists?
    end
  end
end
