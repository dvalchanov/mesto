module Calculators
  class FundingLedger
    def initialize(schedule:, cost_lines:, funding:, mortgage_principal_cents: 0)
      @schedule = schedule.deep_stringify_keys
      @cost_lines = Array(cost_lines).map(&:deep_stringify_keys)
      @funding = funding.to_h.deep_stringify_keys
      @mortgage_principal_cents = mortgage_principal_cents.to_i
    end

    def call
      events = schedule.fetch("events", [])
      return incomplete("Няма пълен график, върху който да се провери финансирането.") if events.empty?
      return incomplete("Въведи наличните собствени средства към началото на плана.") if funding["starting_cash_cents"].nil?

      sources = mortgage_sources
      event_keys = events.map { _1["key"] }
      timing_unknown = mortgage_principal_cents.positive? &&
        (sources.empty? || sources.any? { _1["event_key"].blank? || !event_keys.include?(_1["event_key"]) })
      first_mortgage_event = events.find { |event| sources.any? { _1["event_key"] == event["key"] } }&.fetch("key", nil)
      own_cash = funding["starting_cash_cents"].to_i
      minimum_cash = own_cash
      restricted_loan = 0
      mortgage_released = 0
      mortgage_used = 0
      own_required = 0
      first_shortfall = nil
      rows = events.map do |event|
        own_inflows = funding.fetch("own_inflows", []).select { _1["event_key"] == event["key"] }.sum { _1["amount_cents"].to_i }
        own_cash += own_inflows
        released_here = sources.select { _1["event_key"] == event["key"] }.sum { _1["amount_cents"].to_i }
        released_here = [ released_here, mortgage_principal_cents - mortgage_released ].min
        restricted_loan += released_here
        mortgage_released += released_here

        seller_due = event["remaining_cents"].to_i
        costs_due = costs_for(event["key"])
        loan_applied = [ restricted_loan, seller_due ].min
        restricted_loan -= loan_applied
        mortgage_used += loan_applied
        cash_required = seller_due - loan_applied + costs_due
        own_required += cash_required
        opening_cash = own_cash
        own_cash -= cash_required
        minimum_cash = [ minimum_cash, own_cash ].min
        first_shortfall ||= event["key"] if own_cash.negative?
        {
          "event_key" => event["key"], "label" => event["label"], "date" => event["date"], "date_precision" => event["date_precision"],
          "opening_own_cash_cents" => opening_cash, "own_inflows_cents" => own_inflows,
          "seller_payment_cents" => seller_due, "additional_costs_cents" => costs_due,
          "mortgage_applied_cents" => loan_applied, "own_cash_required_cents" => cash_required,
          "projected_own_cash_cents" => own_cash, "reserve_headroom_cents" => own_cash - reserve_cents
        }
      end

      unscheduled_costs = remaining_cost_lines.reject { |cost| events.any? { _1["key"] == cost["payment_event_key"] } }.sum { _1["remaining_cents"].to_i }
      remaining_seller = events.sum { _1["remaining_cents"].to_i }
      remaining_costs = remaining_cost_lines.sum { _1["remaining_cents"].to_i }
      historical_paid = schedule.fetch("historical_price_paid_cents", 0) + cost_lines.sum { _1["already_paid_cents"].to_i }
      payment_shortfall = [ -minimum_cash, 0 ].max
      reserve_gap = [ reserve_cents - minimum_cash, 0 ].max

      {
        "complete" => schedule["complete"] && !timing_unknown && unscheduled_costs.zero?,
        "rows" => rows,
        "remaining_total_payments_cents" => remaining_seller + remaining_costs,
        "remaining_own_funding_cents" => own_required + unscheduled_costs,
        "lifetime_own_funding_cents" => historical_paid + own_required + unscheduled_costs,
        "historical_paid_cents" => historical_paid,
        "mortgage_applied_cents" => mortgage_used,
        "unused_mortgage_capacity_cents" => mortgage_principal_cents - mortgage_used,
        "planned_mortgage_disbursements_cents" => sources.sum { _1["amount_cents"].to_i },
        "own_funds_before_first_mortgage_cents" => own_before_mortgage(rows, first_mortgage_event),
        "minimum_projected_cash_cents" => minimum_cash,
        "first_shortfall_event_key" => first_shortfall,
        "largest_funding_shortfall_cents" => payment_shortfall,
        "additional_funding_for_reserve_cents" => reserve_gap,
        "reserve_only_shortfall_cents" => payment_shortfall.zero? ? reserve_gap : 0,
        "unscheduled_costs_cents" => unscheduled_costs,
        "warnings" => ledger_warnings(timing_unknown:, unscheduled_costs:)
      }
    end

    private

    attr_reader :schedule, :cost_lines, :funding, :mortgage_principal_cents

    def reserve_cents = funding.fetch("reserve_cents", 0).to_i

    def remaining_cost_lines
      cost_lines.select do |line|
        line["status"] == "calculated" && !line["category"].in?(%w[recurring price_component]) && line["remaining_cents"].to_i.positive?
      end
    end

    def mortgage_sources
      explicit = Array(funding["mortgage_disbursements"]).select { _1["amount_cents"].to_i.positive? }
      return explicit if explicit.any?
      return [] if mortgage_principal_cents.zero? || funding["mortgage_availability_event_key"].blank?

      [ { "key" => "mortgage", "amount_cents" => mortgage_principal_cents,
        "event_key" => funding["mortgage_availability_event_key"], "confidence" => funding["mortgage_confidence"] } ]
    end

    def costs_for(event_key)
      remaining_cost_lines.select { _1["payment_event_key"] == event_key }.sum { _1["remaining_cents"].to_i }
    end

    def own_before_mortgage(rows, mortgage_event)
      return rows.sum { _1["own_cash_required_cents"] } if mortgage_event.blank?

      rows.take_while { _1["event_key"] != mortgage_event }.sum { _1["own_cash_required_cents"] }
    end

    def ledger_warnings(timing_unknown:, unscheduled_costs:)
      warnings = []
      warnings << "Не си посочил от кой момент можеш да използваш ипотечните средства, затова не сме ги включили като налични." if timing_unknown
      warnings << "Сборът на планираните ипотечни усвоявания е над размера на кредита; използването е ограничено до главницата." if mortgage_sources.sum { _1["amount_cents"].to_i } > mortgage_principal_cents
      warnings << "Има разходи без съвпадащо събитие в графика." if unscheduled_costs.positive?
      warnings << "Отрицателното салдо показва недостиг на средства. То не означава, че разполагаш с овърдрафт." if warnings.empty? || rows_negative?
      warnings
    end

    def rows_negative? = false

    def incomplete(message)
      { "complete" => false, "rows" => [], "warnings" => [ message ], "largest_funding_shortfall_cents" => nil,
        "additional_funding_for_reserve_cents" => nil, "remaining_own_funding_cents" => nil }
    end
  end
end
