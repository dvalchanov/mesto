require "bigdecimal"

module Calculators
  class PurchaseCosts
    RULE_KEYS = %w[
      bg.euro_conversion bg.registry.sale_registration bg.notary.material_interest
      bg.vat.standard bg.property_transfer.tax_base
    ].freeze

    def initialize(inputs, catalog: RuleCatalog.new)
      @inputs = inputs.deep_stringify_keys
      @catalog = catalog
      @date = Date.iso8601(@inputs["transaction_date"].presence || @inputs["rule_date"].presence || Date.current.iso8601)
      @municipality = @inputs["municipality"] || "sofia"
    end

    def call
      return blank_result unless property_price_cents

      rules = load_rules
      property_vat = property_vat_line(rules.fetch("bg.vat.standard"))
      payable_price = property_price_cents + additional_components_total + property_vat.fetch("amount_cents", 0).to_i
      tax_base = tax_base_for(payable_price)
      automatic = automatic_lines(rules, tax_base)
      custom = custom_lines(tax_base:, payable_price:, vat_rule: rules.fetch("bg.vat.standard"))
      lines = apply_replacements(automatic + [ property_vat ] + custom + [ reservation_separate_fee_line ].compact)
      totals = totals_for(lines)
      unresolved = lines.select { |line| line["status"] == "unresolved" }

      {
        "complete" => unresolved.empty? && inputs["tax_assessment_cents"].present?,
        "property_price_cents" => property_price_cents,
        "payable_property_price_cents" => payable_price,
        "tax_base_cents" => tax_base,
        "components" => inputs.fetch("components", []),
        "lines" => lines,
        "unresolved_items" => unresolved,
        "acquisition_costs_cents" => totals.fetch("acquisition", 0),
        "financing_costs_cents" => totals.fetch("financing", 0),
        "after_purchase_costs_cents" => totals.fetch("after_purchase", 0),
        "recurring_monthly_costs_cents" => totals.fetch("recurring", 0),
        "included_costs_cents" => totals.except("recurring").values.sum,
        "combined_included_outlay_cents" => payable_price + totals.except("recurring").values.sum,
        "rule_versions" => rules.transform_values { |rule| rule["version"] },
        "warnings" => warnings(unresolved),
        "assumptions" => assumptions(tax_base:)
      }
    rescue RuleCatalog::RuleNotFound => error
      unsupported_rule_result(error.message)
    end

    private

    attr_reader :inputs, :catalog, :date, :municipality

    def property_price_cents = inputs["property_price_cents"]

    def blank_result
      {
        "complete" => false, "property_price_cents" => nil, "payable_property_price_cents" => nil,
        "lines" => [], "unresolved_items" => [], "included_costs_cents" => 0,
        "combined_included_outlay_cents" => nil, "warnings" => [ "Въведи цена, за да започне изчислението." ],
        "rule_versions" => {}
      }
    end

    def unsupported_rule_result(_message)
      payable_price = property_price_cents + additional_components_total
      {
        "complete" => false, "property_price_cents" => property_price_cents,
        "payable_property_price_cents" => payable_price, "tax_base_cents" => tax_base_for(payable_price),
        "lines" => [ unresolved_line("regulatory_rules", "Законови данъци и такси", "acquisition",
          "Няма приложима проверена версия на правилата за тази дата.") ],
        "unresolved_items" => [ { "key" => "regulatory_rules", "status" => "unresolved" } ],
        "acquisition_costs_cents" => 0, "financing_costs_cents" => 0, "after_purchase_costs_cents" => 0,
        "recurring_monthly_costs_cents" => 0, "included_costs_cents" => 0,
        "combined_included_outlay_cents" => payable_price, "rule_versions" => {},
        "warnings" => [ "Проверените автоматични правила не покриват избраната дата. Използвай ръчни оферти." ],
        "assumptions" => []
      }
    end

    def load_rules
      keys = RULE_KEYS.dup
      keys << "bg.sofia.acquisition_tax" if municipality == "sofia"
      keys.index_with { |key| catalog.find(key, date:, municipality:) }
    end

    def additional_components_total
      inputs.fetch("components", []).sum do |component|
        component["price_relation"] == "additional" ? component["amount_cents"].to_i : 0
      end
    end

    def property_vat_line(vat_rule)
      case inputs["price_vat_treatment"]
      when "final"
        line("property_vat", "ДДС върху цената на имота", "price_component", 0, "not_applicable", "user_confirmed_final_price")
      when "net"
        unless inputs["property_vat_confirmed"] && inputs["property_vat_rate"].present?
          return unresolved_line("property_vat", "ДДС върху цената на имота", "price_component", "Потвърди приложимата ставка за нетната оферта.")
        end
        amount = percent(property_price_cents + additional_components_total, inputs["property_vat_rate"])
        line("property_vat", "ДДС върху цената на имота", "price_component", amount, "calculated", "user_confirmed_rate", vat_rule)
      else
        unresolved_line("property_vat", "ДДС върху цената на имота", "price_component", "Не е изяснено дали офертата е крайна или без ДДС.")
      end
    end

    def tax_base_for(payable_price)
      [ payable_price, inputs["tax_assessment_cents"].to_i ].max
    end

    def automatic_lines(rules, tax_base)
      local_tax = if municipality == "sofia"
        rule = rules.fetch("bg.sofia.acquisition_tax")
        line("municipal_acquisition_tax", "Местен данък при придобиване", "acquisition",
          buyer_share(percent(tax_base, rule.dig("parameters", "rate_percent"))), "calculated", "verified_statutory_rule", rule,
          explanation: "3% върху по-високата стойност между уговорената цена и данъчната оценка.")
      elsif inputs["manual_local_tax_rate"].present?
        line("municipal_acquisition_tax", "Местен данък при придобиване", "acquisition",
          buyer_share(percent(tax_base, inputs["manual_local_tax_rate"])), "calculated", "user_entered_percentage", nil,
          explanation: "Ръчно въведена непроверена ставка за избраната община.")
      else
        unresolved_line("municipal_acquisition_tax", "Местен данък при придобиване", "acquisition",
          "Ставката извън София не е проверена. Въведи я ръчно.")
      end

      registration_rule = rules.fetch("bg.registry.sale_registration")
      conversion_rule = rules.fetch("bg.euro_conversion")
      minimum_cents = eur_from_bgn(registration_rule.dig("parameters", "minimum_bgn"), conversion_rule)
      registration = line("sale_registration_fee", "Такса за вписване на продажбата", "acquisition",
        buyer_share([ percent(tax_base, registration_rule.dig("parameters", "rate_percent")), minimum_cents ].max),
        "calculated", "verified_statutory_rule", registration_rule,
        explanation: "0,1% върху материалния интерес, но не по-малко от законовия минимум.")

      notary_rule = rules.fetch("bg.notary.material_interest")
      notary_amount = ProgressiveNotarialFee.new(rule: notary_rule, conversion_rule:).call(tax_base)
      notary = line("main_notarial_fee", "Основна нотариална такса", "acquisition", buyer_share(notary_amount),
        "calculated", "verified_statutory_rule", notary_rule,
        explanation: "Прогресивна тарифа върху материалния интерес; левовите прагове се прилагат преди еднократно превалутиране.")
      vat_rule = rules.fetch("bg.vat.standard")
      notary_vat = line("main_notarial_fee_vat", "ДДС върху нотариалната услуга", "acquisition",
        buyer_share(percent(notary_amount, vat_rule.dig("parameters", "rate_percent"))), "calculated", "verified_statutory_rule", vat_rule,
        explanation: "20% върху изчислената основна нотариална такса.")
      [ local_tax, registration, notary, notary_vat ]
    end

    def custom_lines(tax_base:, payable_price:, vat_rule:)
      inputs.fetch("costs", []).flat_map do |cost|
        next [] unless cost["included"]
        if cost["method"] == "not_applicable"
          next [ line(cost["key"], cost["label"], cost["category"], 0, "not_applicable", "user_entered") ]
        end
        missing_value = cost["method"] == "percentage" ? cost["rate_percent"].blank? : cost["amount_cents"].nil?
        if cost["method"] == "unknown" || missing_value
          next [ unresolved_line(cost["key"], cost["label"], cost["category"], "Избраното перо няма въведена стойност.", cost:) ]
        end

        base = case cost["base"]
        when "tax_base" then tax_base
        when "loan_amount" then inputs.dig("loan", "principal_cents").to_i
        else payable_price
        end
        raw_amount = cost["method"] == "percentage" ? percent(base, cost["rate_percent"]) : cost["amount_cents"].to_i
        amount = percent(raw_amount, cost["buyer_share_percent"] || "100")
        explanation = cost["vat_treatment"] == "uncertain" ? "Нетната или крайната въведена сума е включена, но евентуалният ДДС остава неизвестен." : "Въведена от теб оферта или оценка."
        provenance = cost["method"] == "percentage" ? "user_entered_percentage" : (cost["method"] == "estimate" ? "explicit_estimate" : "user_entered")
        base_line = line(cost["key"], cost["label"], cost["category"], amount, "calculated", provenance, nil,
          explanation:, cost:)
        vat_line = if cost["vat_treatment"] == "exclusive"
          line("#{cost['key']}_vat", "ДДС - #{cost['label']}", cost["category"],
            percent(amount, vat_rule.dig("parameters", "rate_percent")), "calculated", "user_confirmed_exclusive_vat", vat_rule,
            explanation: "20% ДДС върху въведената нетна оферта.", cost: cost.merge("already_paid_cents" => 0))
        elsif cost["vat_treatment"] == "uncertain"
          unresolved_line("#{cost['key']}_vat", "ДДС - #{cost['label']}", cost["category"], explanation, cost:)
        end
        [ base_line, vat_line ].compact
      end
    end

    def apply_replacements(lines)
      replacements = inputs.fetch("costs", []).select { _1["included"] }.flat_map { _1["replaces"] }.uniq
      replacements += [ "main_notarial_fee_vat" ] if replacements.include?("main_notarial_fee")
      lines.reject { |item| replacements.include?(item["key"]) }
    end

    def reservation_separate_fee_line
      reservation = inputs.fetch("reservation", {})
      return unless reservation["treatment"] == "separate_fee" && reservation["amount_cents"].present?

      amount = reservation["amount_cents"].to_i
      line("reservation_separate_fee", "Резервационно плащане като отделна такса", "acquisition", amount,
        "calculated", "user_reported", nil, explanation: "Третирано е като отделен разход, а не като кредит към цената.",
        cost: { "already_paid_cents" => amount, "payment_event_key" => "historical", "buyer_share_percent" => "100" })
    end

    def totals_for(lines)
      lines.each_with_object(Hash.new(0)) do |item, totals|
        next unless item["status"] == "calculated"
        next if item["category"] == "price_component"

        totals[item["category"]] += item["amount_cents"]
      end
    end

    def line(key, label, category, amount, status, provenance, rule = nil, explanation: nil, cost: nil)
      already_paid = cost&.fetch("already_paid_cents", 0).to_i
      {
        "key" => key, "label" => label.presence || key.humanize, "category" => category,
        "amount_cents" => amount.to_i, "status" => status, "provenance" => provenance,
        "already_paid_cents" => already_paid, "remaining_cents" => [ amount.to_i - already_paid, 0 ].max,
        "payment_event_key" => cost&.fetch("payment_event_key", "").presence || default_event(category),
        "explanation" => explanation, "rule_version" => rule&.fetch("version", nil),
        "source_url" => rule&.fetch("source_url", nil), "buyer_share_percent" => cost&.fetch("buyer_share_percent", "100") || "100"
      }
    end

    def unresolved_line(key, label, category, explanation, cost: nil)
      line(key, label, category, 0, "unresolved", "unknown", nil, explanation:, cost:)
    end

    def default_event(category)
      category == "after_purchase" ? "handover" : (category == "recurring" ? "monthly" : "notarial_transfer")
    end

    def warnings(unresolved)
      result = []
      result << "Има непопълнени разходи. Сумата не е окончателна." if unresolved.any?
      result << "Данъчната оценка не е въведена. Законовите пера са условно изчислени върху цената и общата сума не е окончателна." if inputs["tax_assessment_cents"].nil?
      if inputs["transaction_cost_share_percent"] != "100.0" && inputs["transaction_cost_share_percent"] != "100"
        result << "За автоматичните разходи е приложен въведеният от теб планиран дял #{inputs['transaction_cost_share_percent']}%. Това не е твърдение за универсална правна отговорност."
      end
      result << "За бъдеща дата се приема, че правилата няма да се променят." if date > Date.current
      result << "Изчислението е за една стандартна жилищна продажба; смесено данъчно третиране и няколко нотариални акта изискват ръчни оферти."
      result
    end

    def assumptions(tax_base:)
      assessment = inputs["tax_assessment_cents"]
      [
        assessment ? "Материалният интерес е по-високата стойност между цената и въведената данъчна оценка." : "Няма въведена данъчна оценка; условно е използвана цената.",
        "Разпределението на разходите е планирано от купувача и не твърди универсална правна отговорност."
      ]
    end

    def percent(cents, rate)
      (BigDecimal(cents.to_s) * BigDecimal(rate.to_s) / 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end

    def buyer_share(cents)
      percent(cents, inputs["transaction_cost_share_percent"] || "100")
    end

    def eur_from_bgn(amount_bgn, conversion_rule)
      rate = BigDecimal(conversion_rule.dig("parameters", "bgn_per_eur"))
      (BigDecimal(amount_bgn.to_s) / rate * 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end
  end
end
