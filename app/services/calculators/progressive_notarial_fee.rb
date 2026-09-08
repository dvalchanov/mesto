require "bigdecimal"

module Calculators
  class ProgressiveNotarialFee
    def initialize(rule:, conversion_rule:)
      @rule = rule
      @conversion_rule = conversion_rule
    end

    def call(material_interest_cents)
      interest_eur = BigDecimal(material_interest_cents.to_s) / 100
      interest_bgn = interest_eur * bgn_per_eur
      bracket = brackets.find { |item| item["up_to_bgn"].nil? || interest_bgn <= decimal(item["up_to_bgn"]) }
      fee_bgn = decimal(bracket["fixed_bgn"]) +
        ([ interest_bgn - decimal(bracket["excess_over_bgn"]), 0 ].max * decimal(bracket["excess_rate_percent"]) / 100)
      fee_bgn = [ fee_bgn, decimal(rule.dig("parameters", "maximum_bgn")) ].min
      ((fee_bgn / bgn_per_eur) * 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end

    private

    attr_reader :rule, :conversion_rule

    def brackets = rule.dig("parameters", "brackets")
    def bgn_per_eur = decimal(conversion_rule.dig("parameters", "bgn_per_eur"))
    def decimal(value) = BigDecimal(value.to_s)
  end
end
