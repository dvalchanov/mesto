module Education
  class ChecklistBuilder
    def initialize(journey:, context:, assessment: nil, catalog: Catalog.instance)
      @journey = journey
      @context = context.stringify_keys
      @assessment = assessment
      @catalog = catalog
    end

    def call
      relevant_keys = RuleEngine.new(@context, catalog: @catalog).matches.flat_map { |rule| Array(rule.dig("then", "task_keys")) }.uniq
      historical_keys = @journey&.journey_item_progresses&.select { |item| item.item_kind == "task" }&.map(&:item_key) || []
      later_keys = next_stage_task_keys - relevant_keys
      conditional_keys = @context["financing_context"] == "undecided" ? [ "task.financing_plan" ] : []
      keys = relevant_keys + historical_keys + later_keys.first(2) + conditional_keys

      keys.uniq.filter_map do |key|
        definition = @catalog.checklist_item(key)
        next unless definition

        progress = @journey&.journey_item_progresses&.find { |item| item.item_kind == "task" && item.item_key == key }
        definition.merge(
          "applicability" => applicability(key, relevant_keys, historical_keys, later_keys, conditional_keys),
          "user_progress" => progress&.status || "not_started",
          "content_version" => definition.fetch("content_version", 1),
          "evidence" => evidence_for(definition)
        )
      end
    end

    private

    def evidence_for(definition)
      return { "status" => definition.fetch("default_evidence", "separate_official_check_needed") } unless @assessment

      expected = definition["evidenced_milestone"]
      if expected && @assessment.milestone == expected
        { "status" => "directly_found", "date" => @assessment.evidence_date, "scope" => @assessment.subject_scope }
      elsif expected
        { "status" => @assessment.source_checked_at ? "no_matching_record_found" : "source_unavailable" }
      else
        { "status" => definition.fetch("default_evidence", "requested_from_seller") }
      end
    end

    def next_stage_task_keys
      stages = BuyerJourney::BUYER_STAGES
      current_index = stages.index(@context["buyer_stage"])
      return [] if @context["buyer_stage"].in?(%w[owner unknown])
      return [] unless current_index && current_index < stages.length - 1

      next_context = @context.merge("buyer_stage" => stages[current_index + 1])
      RuleEngine.new(next_context, catalog: @catalog).matches.flat_map { |rule| Array(rule.dig("then", "task_keys")) }.uniq
    end

    def applicability(key, relevant, historical, later, conditional)
      return "relevant_now" if relevant.include?(key)
      return "not_applicable" if historical.include?(key)
      return "later" if later.include?(key)
      return "conditional" if conditional.include?(key)

      "not_applicable"
    end
  end
end
