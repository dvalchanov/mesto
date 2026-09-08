module Calculators
  class ScenarioComparison
    METRICS = {
      "included_outlay_cents" => %w[costs combined_included_outlay_cents],
      "own_funding_cents" => %w[funding remaining_own_funding_cents],
      "monthly_payment_cents" => %w[mortgage regular_payment_cents],
      "total_interest_cents" => %w[mortgage total_interest_cents],
      "peak_shortfall_cents" => %w[funding largest_funding_shortfall_cents]
    }.freeze

    def initialize(first, second)
      @first = first.deep_stringify_keys
      @second = second.deep_stringify_keys
    end

    def call
      values = METRICS.transform_values do |path|
        left = first.dig(*path)
        right = second.dig(*path)
        { "first" => left, "second" => right, "difference" => left && right ? right - left : nil }
      end
      left_assumptions = Array(first["assumptions"])
      right_assumptions = Array(second["assumptions"])
      { "metrics" => values, "assumption_differences" => (left_assumptions - right_assumptions) + (right_assumptions - left_assumptions) }
    end

    private

    attr_reader :first, :second
  end
end
