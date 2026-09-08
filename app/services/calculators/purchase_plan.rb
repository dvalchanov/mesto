module Calculators
  class PurchasePlan
    ENGINE_VERSION = "1.0.0"

    def initialize(inputs, catalog: RuleCatalog.new)
      @inputs = inputs.deep_stringify_keys
      @catalog = catalog
    end

    def call
      costs = PurchaseCosts.new(inputs, catalog:).call
      principal = loan_principal(costs["payable_property_price_cents"])
      mortgage = if inputs["financing_mode"] == "mortgage"
        loan = inputs.fetch("loan", {})
        Mortgage.new(principal_cents: principal, annual_interest_rate: loan["annual_interest_rate"],
          term_months: loan["term_months"], monthly_charges_cents: loan["monthly_charges_cents"]).call
      else
        { "complete" => true, "principal_cents" => 0, "schedule" => [], "regular_payment_cents" => 0,
          "total_interest_cents" => 0, "total_principal_and_interest_cents" => 0, "monthly_charges_cents" => 0,
          "total_regular_monthly_outflow_cents" => costs["recurring_monthly_costs_cents"].to_i }
      end
      if mortgage["complete"]
        mortgage["other_housing_costs_cents"] = costs["recurring_monthly_costs_cents"].to_i
        mortgage["total_regular_monthly_outflow_cents"] = mortgage["regular_payment_cents"].to_i +
          mortgage["monthly_charges_cents"].to_i + mortgage["other_housing_costs_cents"]
      end
      schedule = PaymentSchedule.new(property_price_cents: costs["payable_property_price_cents"],
        events: inputs.fetch("schedule", []), reservation: inputs.fetch("reservation", {})).call
      funding = FundingLedger.new(schedule:, cost_lines: costs.fetch("lines", []), funding: inputs.fetch("funding", {}),
        mortgage_principal_cents: principal.to_i).call
      required_own = costs["combined_included_outlay_cents"] && [ costs["combined_included_outlay_cents"] - principal.to_i, 0 ].max

      {
        "engine_version" => ENGINE_VERSION,
        "complete" => costs["complete"] && mortgage["complete"] && schedule["complete"] && funding["complete"],
        "costs" => costs, "mortgage" => mortgage, "schedule" => schedule, "funding" => funding,
        "required_own_funds_cents" => required_own,
        "rule_versions" => costs["rule_versions"],
        "warnings" => [ *costs["warnings"], *mortgage["warnings"], *schedule["errors"], *schedule["warnings"], *funding["warnings"] ].compact.uniq,
        "assumptions" => [ *costs["assumptions"], *mortgage["assumptions"] ].compact.uniq
      }
    end

    private

    attr_reader :inputs, :catalog

    def loan_principal(payable_price)
      return 0 unless inputs["financing_mode"] == "mortgage"

      loan = inputs.fetch("loan", {})
      if loan["primary_input"] == "own_contribution" && payable_price && loan["own_contribution_cents"]
        [ payable_price - loan["own_contribution_cents"], 0 ].max
      elsif loan["principal_cents"].nil? && loan["bank_valuation_cents"] && loan["assumed_financing_percentage"]
        (BigDecimal(loan["bank_valuation_cents"].to_s) * BigDecimal(loan["assumed_financing_percentage"].to_s) / 100)
          .round(0, BigDecimal::ROUND_HALF_UP).to_i
      else
        loan["principal_cents"]
      end
    end
  end
end
