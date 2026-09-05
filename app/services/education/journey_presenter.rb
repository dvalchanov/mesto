module Education
  class JourneyPresenter
    attr_reader :journey, :analysis, :assessment, :recommendations, :checklist

    def initialize(journey:, analysis: nil, visible_acts: nil, catalog: Catalog.instance)
      @journey = journey
      @analysis = analysis || journey&.property_analysis
      @catalog = catalog
      @assessment = if @analysis
        BuildingMilestoneResolver.new(
          analysis: @analysis,
          reported_stage: journey&.user_reported_building_stage,
          visible_acts:
        ).call
      end
      @context = build_context
      @recommendations = RecommendationEngine.new(@context, catalog:).call
      @checklist = ChecklistBuilder.new(journey:, context: @context, assessment:, catalog:).call
    end

    def buyer_stage
      journey&.buyer_stage || "unknown"
    end

    def previous_buyer_stage
      adjacent_buyer_stage(-1)
    end

    def next_buyer_stage
      adjacent_buyer_stage(1)
    end

    def completed_task_count
      checklist.count { |item| item["user_progress"] == "done" }
    end

    def questions
      checklist.filter_map { |item| item["question"] }.first(7)
    end

    def priority_recommendations
      action_guidance = recommendations.reject { |item| item["path_kind"].in?(%w[document term]) }
      (action_guidance.presence || recommendations).first(5)
    end

    def concepts
      recommendations.select { |item| item["path_kind"].in?(%w[document term]) }.first(3)
    end

    private

    def build_context
      {
        "buyer_stage" => journey&.buyer_stage || "researching",
        "property_type" => journey&.property_type || "undecided",
        "reported_milestone" => journey&.user_reported_building_stage || "unknown",
        "evidenced_milestone" => assessment&.milestone || "unknown",
        "financing_context" => journey&.financing_context || "undecided",
        "source_coverage" => analysis ? ReportEvidenceAdapter.new(analysis:).source_coverage : "not_applicable",
        "property_connected" => analysis ? "yes" : "no"
      }
    end

    def adjacent_buyer_stage(offset)
      index = BuyerJourney::BUYER_STAGES.index(buyer_stage)
      return unless index

      BuyerJourney::BUYER_STAGES[index + offset] if (index + offset).between?(0, BuyerJourney::BUYER_STAGES.length - 1)
    end
  end
end
