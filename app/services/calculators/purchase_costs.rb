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
        "combined_included_outlay_cents" => nil, "warnings" => [ copy("Въведи цена, за да започне изчислението.", "Enter a property price to start the calculation.") ],
        "rule_versions" => {}
      }
    end

    def unsupported_rule_result(_message)
      payable_price = property_price_cents + additional_components_total
      {
        "complete" => false, "property_price_cents" => property_price_cents,
        "payable_property_price_cents" => payable_price, "tax_base_cents" => tax_base_for(payable_price),
        "lines" => [ unresolved_line("regulatory_rules", copy("Законови данъци и такси", "Statutory taxes and fees"), "acquisition",
          copy("Няма приложима проверена версия на правилата за тази дата.", "No verified version of the rules applies on this date.")) ],
        "unresolved_items" => [ { "key" => "regulatory_rules", "status" => "unresolved" } ],
        "acquisition_costs_cents" => 0, "financing_costs_cents" => 0, "after_purchase_costs_cents" => 0,
        "recurring_monthly_costs_cents" => 0, "included_costs_cents" => 0,
        "combined_included_outlay_cents" => payable_price, "rule_versions" => {},
        "warnings" => [ copy("Проверените правила не важат за избраната дата. Въведи сумите ръчно по актуални оферти.", "The verified rules do not apply on the selected date. Enter the amounts manually using current quotes.") ],
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
        line("property_vat", copy("ДДС върху цената на имота", "VAT on the property price"), "price_component", 0, "not_applicable", "user_confirmed_final_price")
      when "net"
        unless inputs["property_vat_confirmed"] && inputs["property_vat_rate"].present?
          return unresolved_line("property_vat", copy("ДДС върху цената на имота", "VAT on the property price"), "price_component", copy("Потвърди приложимата ставка за нетната оферта.", "Confirm the VAT rate that applies to the net offer."))
        end
        amount = percent(property_price_cents + additional_components_total, inputs["property_vat_rate"])
        line("property_vat", copy("ДДС върху цената на имота", "VAT on the property price"), "price_component", amount, "calculated", "user_confirmed_rate", vat_rule)
      else
        unresolved_line("property_vat", copy("ДДС върху цената на имота", "VAT on the property price"), "price_component", copy("Не е изяснено дали офертата е крайна или без ДДС.", "It is unclear whether the offer is a final price or excludes VAT."))
      end
    end

    def tax_base_for(payable_price)
      [ payable_price, inputs["tax_assessment_cents"].to_i ].max
    end

    def automatic_lines(rules, tax_base)
      local_tax = if municipality == "sofia"
        rule = rules.fetch("bg.sofia.acquisition_tax")
        line("municipal_acquisition_tax", copy("Местен данък при придобиване", "Local property transfer tax"), "acquisition",
          buyer_share(percent(tax_base, rule.dig("parameters", "rate_percent"))), "calculated", "verified_statutory_rule", rule,
          explanation: copy("3% върху по-високата стойност между уговорената цена и данъчната оценка.", "3% of the higher of the agreed price and the tax valuation."))
      elsif inputs["manual_local_tax_rate"].present?
        line("municipal_acquisition_tax", copy("Местен данък при придобиване", "Local property transfer tax"), "acquisition",
          buyer_share(percent(tax_base, inputs["manual_local_tax_rate"])), "calculated", "user_entered_percentage", nil,
          explanation: copy("Ръчно въведена непроверена ставка за избраната община.", "An unverified rate entered manually for the selected municipality."))
      else
        unresolved_line("municipal_acquisition_tax", copy("Местен данък при придобиване", "Local property transfer tax"), "acquisition",
          copy("Ставката извън София не е проверена. Въведи я ръчно.", "The rate outside Sofia has not been verified. Enter it manually."))
      end

      registration_rule = rules.fetch("bg.registry.sale_registration")
      conversion_rule = rules.fetch("bg.euro_conversion")
      minimum_cents = eur_from_bgn(registration_rule.dig("parameters", "minimum_bgn"), conversion_rule)
      registration = line("sale_registration_fee", copy("Такса за вписване на продажбата", "Sale registration fee"), "acquisition",
        buyer_share([ percent(tax_base, registration_rule.dig("parameters", "rate_percent")), minimum_cents ].max),
        "calculated", "verified_statutory_rule", registration_rule,
        explanation: copy("0,1% върху материалния интерес, но не по-малко от законовия минимум.", "0.1% of the material interest, subject to the statutory minimum."))

      notary_rule = rules.fetch("bg.notary.material_interest")
      notary_amount = ProgressiveNotarialFee.new(rule: notary_rule, conversion_rule:).call(tax_base)
      notary = line("main_notarial_fee", copy("Основна нотариална такса", "Basic notary fee"), "acquisition", buyer_share(notary_amount),
        "calculated", "verified_statutory_rule", notary_rule,
        explanation: copy("Прогресивна тарифа върху материалния интерес; левовите прагове се прилагат преди еднократно превалутиране.", "A progressive tariff based on the material interest; BGN thresholds are applied before a single conversion to euros."))
      vat_rule = rules.fetch("bg.vat.standard")
      notary_vat = line("main_notarial_fee_vat", copy("ДДС върху нотариалната услуга", "VAT on the notary service"), "acquisition",
        buyer_share(percent(notary_amount, vat_rule.dig("parameters", "rate_percent"))), "calculated", "verified_statutory_rule", vat_rule,
        explanation: copy("20% върху изчислената основна нотариална такса.", "20% of the calculated basic notary fee."))
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
          next [ unresolved_line(cost["key"], cost["label"], cost["category"], copy("Избраното перо няма въведена стойност.", "No value has been entered for this cost."), cost:) ]
        end

        base = case cost["base"]
        when "tax_base" then tax_base
        when "loan_amount" then inputs.dig("loan", "principal_cents").to_i
        else payable_price
        end
        raw_amount = cost["method"] == "percentage" ? percent(base, cost["rate_percent"]) : cost["amount_cents"].to_i
        amount = percent(raw_amount, cost["buyer_share_percent"] || "100")
        explanation = cost["vat_treatment"] == "uncertain" ? copy("Въведената сума е включена, но не е ясно дали към нея трябва да се добави ДДС.", "The entered amount is included, but it is unclear whether VAT should be added.") : copy("Въведена от теб оферта или приблизителна оценка.", "A quote or estimate entered by you.")
        provenance = cost["method"] == "percentage" ? "user_entered_percentage" : (cost["method"] == "estimate" ? "explicit_estimate" : "user_entered")
        base_line = line(cost["key"], cost["label"], cost["category"], amount, "calculated", provenance, nil,
          explanation:, cost:)
        vat_line = if cost["vat_treatment"] == "exclusive"
          line("#{cost['key']}_vat", "#{copy('ДДС', 'VAT')} - #{cost['label']}", cost["category"],
            percent(amount, vat_rule.dig("parameters", "rate_percent")), "calculated", "user_confirmed_exclusive_vat", vat_rule,
            explanation: copy("20% ДДС върху въведената нетна оферта.", "20% VAT on the entered net quote."), cost: cost.merge("already_paid_cents" => 0))
        elsif cost["vat_treatment"] == "uncertain"
          unresolved_line("#{cost['key']}_vat", "#{copy('ДДС', 'VAT')} - #{cost['label']}", cost["category"], explanation, cost:)
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
      line("reservation_separate_fee", copy("Резервационно плащане като отделна такса", "Reservation payment treated as a separate fee"), "acquisition", amount,
        "calculated", "user_reported", nil, explanation: copy("Третирано е като отделен разход, а не като приспадане от цената.", "Treated as a separate cost rather than a deduction from the price."),
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
      result << copy("Има непопълнени разходи. Сумата не е окончателна.", "Some costs are incomplete, so the total is not final.") if unresolved.any?
      result << copy("Не си въвел данъчна оценка. Затова данъкът и таксите са ориентировъчно изчислени върху цената и общата сума не е окончателна.", "No tax valuation has been entered. The tax and fees are therefore estimated using the price, and the total is not final.") if inputs["tax_assessment_cents"].nil?
      if inputs["transaction_cost_share_percent"] != "100.0" && inputs["transaction_cost_share_percent"] != "100"
        result << copy("За автоматичните разходи е приложен въведеният от теб дял от #{inputs['transaction_cost_share_percent']}%. Той служи само за тази сметка и не определя кой по закон дължи разхода.", "Your entered share of #{inputs['transaction_cost_share_percent']}% has been applied to the automatic costs. It is used only for this calculation and does not determine who is legally liable for the cost.")
      end
      result << copy("За бъдеща дата се приема, че правилата няма да се променят.", "For a future date, the calculation assumes that the rules will not change.") if date > Date.current
      result << copy("Сметката приема една стандартна жилищна продажба. При смесено данъчно третиране или няколко нотариални акта въведи актуални оферти ръчно.", "The calculation assumes a standard residential sale. For mixed tax treatment or multiple notarial deeds, enter current quotes manually.")
      result
    end

    def assumptions(tax_base:)
      assessment = inputs["tax_assessment_cents"]
      [
        assessment ? copy("Материалният интерес е по-високата стойност между цената и въведената данъчна оценка.", "The material interest is the higher of the price and the entered tax valuation.") : copy("Няма въведена данъчна оценка, затова за ориентир е използвана цената.", "No tax valuation has been entered, so the price is used as an estimate."),
        copy("Посоченият дял от разходите служи само за тази сметка и не определя кой по закон ги дължи.", "The stated share of costs is used only for this calculation and does not determine who is legally liable for them.")
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

    def copy(bg, en) = LocalizedCopy.call(bg, en)
  end
end
