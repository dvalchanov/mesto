require "bigdecimal"

module Calculators
  class InputNormalizer
    MAX_MONEY_CENTS = 100_000_000_000
    MAX_TERM_MONTHS = 600

    attr_reader :errors

    def initialize
      @errors = {}
    end

    def self.money_cents(value)
      return if value.nil? || value.to_s.strip.empty?

      normalized = normalize_number_string(value, decimal_places: 2)
      cents = (BigDecimal(normalized) * 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
      raise ArgumentError, "amount_out_of_range" if cents.negative? || cents > MAX_MONEY_CENTS

      cents
    end

    def self.decimal(value, minimum: nil, maximum: nil)
      return if value.nil? || value.to_s.strip.empty?

      number = BigDecimal(normalize_number_string(value, decimal_places: 6))
      raise ArgumentError, "number_below_minimum" if minimum && number < BigDecimal(minimum.to_s)
      raise ArgumentError, "number_above_maximum" if maximum && number > BigDecimal(maximum.to_s)

      number
    end

    def self.integer(value, minimum: nil, maximum: nil)
      return if value.nil? || value.to_s.strip.empty?

      string = value.to_s.strip
      raise ArgumentError, "invalid_integer" unless string.match?(/\A\d+\z/)

      number = Integer(string, 10)
      raise ArgumentError, "number_below_minimum" if minimum && number < minimum
      raise ArgumentError, "number_above_maximum" if maximum && number > maximum

      number
    end

    def purchase(raw)
      data = raw.to_h.deep_stringify_keys
      transaction_date = normalize_date(data["transaction_date"])
      normalized = {
        "property_price_cents" => capture("property_price", data["property_price"]) { self.class.money_cents(_1) },
        "municipality" => data["municipality"].presence_in(%w[sofia other]) || "sofia",
        "transaction_date" => transaction_date,
        "rule_date" => transaction_date || Date.current.iso8601,
        "tax_assessment_cents" => capture("tax_assessment", data["tax_assessment"]) { self.class.money_cents(_1) },
        "financing_mode" => data["financing_mode"].presence_in(%w[own_funds mortgage]) || "own_funds",
        "price_vat_treatment" => data["price_vat_treatment"].presence_in(%w[final net uncertain]) || "final",
        "property_vat_confirmed" => truthy?(data["property_vat_confirmed"]),
        "property_vat_rate" => decimal_value("property_vat_rate", data["property_vat_rate"], minimum: 0, maximum: 100),
        "manual_local_tax_rate" => decimal_value("manual_local_tax_rate", data["manual_local_tax_rate"], minimum: 0, maximum: 10),
        "transaction_cost_share_percent" => decimal_value("transaction_cost_share", data["transaction_cost_share"].presence || "100", minimum: 0, maximum: 100),
        "components" => normalize_components(data["components"]),
        "costs" => normalize_costs(data["costs"]),
        "loan" => normalize_loan(data),
        "schedule" => normalize_schedule(data["schedule"]),
        "reservation" => normalize_reservation(data["reservation"]),
        "funding" => normalize_funding(data),
        "title" => data["title"].to_s.strip.first(80),
        "buyer_journey_id" => capture("buyer_journey_id", data["buyer_journey_id"]) { self.class.integer(_1, minimum: 1) }
      }
      errors["property_price"] = copy("Цената трябва да е по-голяма от нула.", "The property price must be greater than zero.") if normalized["property_price_cents"] == 0
      errors["tax_assessment"] = copy("Данъчната оценка трябва да е по-голяма от нула.", "The tax valuation must be greater than zero.") if normalized["tax_assessment_cents"] == 0
      normalized
    end

    def mortgage(raw)
      data = raw.to_h.deep_stringify_keys
      {
        "principal_cents" => capture("principal", data["principal"]) { self.class.money_cents(_1) },
        "annual_interest_rate" => decimal_value("annual_interest_rate", data["annual_interest_rate"], minimum: 0, maximum: 100),
        "term_months" => term_months(data),
        "monthly_charges_cents" => capture("monthly_charges", data["monthly_charges"]) { self.class.money_cents(_1) } || 0
      }
    end

    private

    def self.normalize_number_string(value, decimal_places:)
      string = value.to_s.strip.tr("\u00A0\u202F", "  ")
      raise ArgumentError, "negative_not_allowed" if string.start_with?("-")
      raise ArgumentError, "ambiguous_number" if string.include?(",") && string.include?(".")

      separator = string.include?(",") ? "," : (string.include?(".") ? "." : nil)
      integer, fraction = separator ? string.split(separator, -1) : [ string, nil ]
      raise ArgumentError, "ambiguous_number" if fraction&.length == 3
      raise ArgumentError, "invalid_number" if fraction && (fraction.empty? || fraction.length > decimal_places)
      raise ArgumentError, "invalid_grouping" unless integer.match?(/\A(?:\d+|\d{1,3}(?: \d{3})+)\z/)
      raise ArgumentError, "invalid_number" if fraction && !fraction.match?(/\A\d+\z/)

      "#{integer.delete(' ')}#{fraction ? ".#{fraction}" : ''}"
    end

    def capture(key, value)
      yield(value)
    rescue ArgumentError
      errors[key] = copy("Въведи положително число, например 300 000,50.", "Enter a positive number, for example 300,000.50.")
      nil
    end

    def decimal_value(key, value, **limits)
      capture(key, value) { self.class.decimal(_1, **limits)&.to_s("F") }
    end

    def normalize_date(value)
      return if value.blank?

      Date.iso8601(value.to_s).iso8601
    rescue Date::Error
      errors["transaction_date"] = copy("Въведи валидна дата.", "Enter a valid date.")
      nil
    end

    def normalize_components(raw)
      collection(raw).first(10).filter_map do |key, value|
        row = value.to_h.stringify_keys
        amount = capture("components.#{key}.amount", row["amount"]) { self.class.money_cents(_1) }
        next if amount.nil? && row["label"].blank?

        { "key" => safe_key(row["key"].presence || key), "label" => row["label"].to_s.first(80),
          "amount_cents" => amount, "price_relation" => row["price_relation"].presence_in(%w[included additional]) || "included" }
      end
    end

    def copy(bg, en) = LocalizedCopy.call(bg, en)

    def normalize_costs(raw)
      collection(raw).first(30).map do |key, value|
        row = value.to_h.stringify_keys
        {
          "key" => safe_key(row["key"].presence || key), "label" => row["label"].to_s.first(80),
          "category" => row["category"].presence_in(%w[acquisition financing after_purchase recurring]) || "acquisition",
          "included" => truthy?(row["included"]),
          "method" => row["method"].presence_in(%w[fixed_quote percentage estimate unknown not_applicable]) || "fixed_quote",
          "amount_cents" => capture("costs.#{key}.amount", row["amount"]) { self.class.money_cents(_1) },
          "rate_percent" => decimal_value("costs.#{key}.rate", row["rate"], minimum: 0, maximum: 100),
          "base" => row["base"].presence_in(%w[property_price tax_base loan_amount fixed]) || "property_price",
          "vat_treatment" => row["vat_treatment"].presence_in(%w[inclusive exclusive uncertain not_applicable]) || "inclusive",
          "buyer_share_percent" => decimal_value("costs.#{key}.buyer_share", row["buyer_share"].presence || "100", minimum: 0, maximum: 100),
          "payment_event_key" => safe_key(row["payment_event_key"]),
          "already_paid_cents" => capture("costs.#{key}.already_paid", row["already_paid"]) { self.class.money_cents(_1) } || 0,
          "replaces" => Array(row["replaces"]).map { safe_key(_1) }.first(10)
        }
      end
    end

    def normalize_loan(data)
      primary = data["loan_primary_input"].presence_in(%w[principal own_contribution]) || "principal"
      {
        "primary_input" => primary,
        "principal_cents" => capture("loan_principal", data["loan_principal"]) { self.class.money_cents(_1) },
        "own_contribution_cents" => capture("own_contribution", data["own_contribution"]) { self.class.money_cents(_1) },
        "annual_interest_rate" => decimal_value("annual_interest_rate", data["annual_interest_rate"], minimum: 0, maximum: 100),
        "term_months" => term_months(data),
        "monthly_charges_cents" => capture("monthly_charges", data["monthly_charges"]) { self.class.money_cents(_1) } || 0,
        "bank_valuation_cents" => capture("bank_valuation", data["bank_valuation"]) { self.class.money_cents(_1) },
        "assumed_financing_percentage" => decimal_value("assumed_financing_percentage", data["assumed_financing_percentage"], minimum: 0, maximum: 100)
      }
    end

    def term_months(data)
      if data["term_months"].present?
        capture("term_months", data["term_months"]) { self.class.integer(_1, minimum: 1, maximum: MAX_TERM_MONTHS) }
      elsif data["term_years"].present?
        years = capture("term_years", data["term_years"]) { self.class.integer(_1, minimum: 1, maximum: 50) }
        years * 12 if years
      end
    end

    def normalize_schedule(raw)
      collection(raw).first(20).map.with_index do |(key, value), index|
        row = value.to_h.stringify_keys
        {
          "key" => safe_key(row["key"].presence || key), "label" => row["label"].to_s.first(80),
          "order" => capture("schedule.#{key}.order", row["order"]) { self.class.integer(_1, minimum: 0, maximum: 1000) } || index,
          "date_precision" => row["date_precision"].presence_in(%w[exact estimated unknown]) || "unknown",
          "date" => safe_date(row["date"]),
          "amount_type" => row["amount_type"].presence_in(%w[fixed percentage remaining]) || "percentage",
          "amount_cents" => capture("schedule.#{key}.amount", row["amount"]) { self.class.money_cents(_1) },
          "percentage" => decimal_value("schedule.#{key}.percentage", row["percentage"], minimum: 0, maximum: 100),
          "percentage_base" => row["percentage_base"].presence_in(%w[property_price]) || "property_price",
          "already_paid_cents" => capture("schedule.#{key}.already_paid", row["already_paid"]) { self.class.money_cents(_1) } || 0
        }
      end.sort_by { |row| [ row["date"].presence || "9999-12-31", row["order"] ] }
    end

    def normalize_reservation(raw)
      row = raw.to_h.stringify_keys
      {
        "amount_cents" => capture("reservation.amount", row["amount"]) { self.class.money_cents(_1) },
        "treatment" => row["treatment"].presence_in(%w[credited separate_fee uncertain not_applicable]) || "not_applicable",
        "credit_event_key" => safe_key(row["credit_event_key"]),
        "paid_before_start" => truthy?(row["paid_before_start"])
      }
    end

    def normalize_funding(data)
      {
        "starting_cash_cents" => capture("starting_cash", data["starting_cash"]) { self.class.money_cents(_1) },
        "reserve_cents" => capture("reserve", data["reserve"]) { self.class.money_cents(_1) } || 0,
        "mortgage_availability_event_key" => safe_key(data["mortgage_availability_event_key"]),
        "mortgage_confidence" => data["mortgage_confidence"].presence_in(%w[hypothetical expected confirmed]) || "hypothetical",
        "mortgage_disbursements" => collection(data["mortgage_disbursements"]).first(10).map do |key, value|
          row = value.to_h.stringify_keys
          { "key" => safe_key(key), "amount_cents" => capture("mortgage_disbursements.#{key}.amount", row["amount"]) { self.class.money_cents(_1) },
            "event_key" => safe_key(row["event_key"]), "confidence" => row["confidence"].presence_in(%w[hypothetical expected confirmed]) || "hypothetical" }
        end,
        "own_inflows" => collection(data["own_inflows"]).first(10).map do |key, value|
          row = value.to_h.stringify_keys
          { "key" => safe_key(key), "amount_cents" => capture("own_inflows.#{key}.amount", row["amount"]) { self.class.money_cents(_1) },
            "event_key" => safe_key(row["event_key"]), "confidence" => row["confidence"].presence_in(%w[hypothetical expected confirmed]) || "expected" }
        end
      }
    end

    def collection(value)
      value.respond_to?(:to_h) ? value.to_h.to_a : []
    end

    def safe_key(value)
      value.to_s.gsub(/[^a-zA-Z0-9_.-]/, "").first(80)
    end

    def safe_date(value)
      Date.iso8601(value.to_s).iso8601 if value.present?
    rescue Date::Error
      nil
    end

    def truthy?(value)
      value.to_s.in?(%w[1 true yes on])
    end
  end
end
