module CalculatorsHelper
  CALCULATOR_COSTS = [
    { key: "additional_notarial", label: "Допълнителни нотариални и документни услуги", description: "Допълнителни удостоверявания, преписи или услуги извън автоматично изчислената основна такса.", category: "acquisition", event: "notarial_transfer" },
    { key: "notary_actual_quote", label: "Обща оферта за основната нотариална услуга", description: "Използвай само ако имаш обща оферта от нотариус. Тя ще замени автоматично изчислената основна нотариална такса.", category: "acquisition", event: "notarial_transfer", replaces: [ "main_notarial_fee" ] },
    { key: "buyer_broker", label: "Комисиона на брокер за купувача", description: "Комисионата, която ти плащаш според договора с брокера - като сума или процент.", category: "acquisition", event: "notarial_transfer", percentage: true },
    { key: "lawyer", label: "Адвокат", description: "Договорена сума за правен преглед или съдействие по сделката.", category: "acquisition", event: "notarial_transfer" },
    { key: "technical_inspection", label: "Технически оглед", description: "Оглед от инженер или технически специалист преди покупката.", category: "acquisition", event: "first" },
    { key: "certificates", label: "Удостоверения и документи", description: "Платени удостоверения, скици, схеми, преписи и други документи.", category: "acquisition", event: "notarial_transfer" },
    { key: "bank_valuation", label: "Банкова оценка", description: "Таксата за оценка на имота, поискана от банката.", category: "financing", event: "first" },
    { key: "lender_setup", label: "Банкови такси за учредяване", description: "Еднократни банкови такси за разглеждане и учредяване на кредита.", category: "financing", event: "notarial_transfer" },
    { key: "mortgage_notary", label: "Нотариални разходи за ипотеката", description: "Нотариални такси, свързани с договора и акта за ипотека.", category: "financing", event: "notarial_transfer" },
    { key: "mortgage_registration", label: "Вписване на ипотеката", description: "Таксата за вписване на ипотеката в Имотния регистър.", category: "financing", event: "notarial_transfer" },
    { key: "other_financing", label: "Друг разход по финансирането", description: "Друг еднократен разход по кредита, който не е включен по-горе.", category: "financing", event: "notarial_transfer" },
    { key: "renovation", label: "Ремонт", description: "Ориентировъчен бюджет или оферта за работи след придобиването.", category: "after_purchase", event: "handover" },
    { key: "furnishing", label: "Обзавеждане", description: "Планирана сума за мебели, техника и оборудване.", category: "after_purchase", event: "handover" },
    { key: "moving", label: "Преместване", description: "Транспорт, хамали и други разходи по преместването.", category: "after_purchase", event: "handover" },
    { key: "custom_after_purchase", label: "Друг разход след покупката", description: "Друг еднократен разход, който искаш да включиш в общия бюджет.", category: "after_purchase", event: "handover" },
    { key: "insurance", label: "Месечна застраховка", description: "Очакваната месечна премия за свързана с имота застраховка.", category: "recurring", event: "monthly" },
    { key: "housing_monthly", label: "Други месечни жилищни разходи", description: "Друг повтарящ се месечен разход, който искаш да виждаш в плана.", category: "recurring", event: "monthly" }
  ].freeze

  COST_CATEGORIES = {
    "acquisition" => { label: "Около сделката", description: "Услуги и професионална помощ преди нотариалното прехвърляне." },
    "financing" => { label: "При ипотека", description: "Разходи, които възникват само ако използваш банково финансиране." },
    "after_purchase" => { label: "След покупката", description: "Еднократни суми за нанасяне и подготовка на имота." },
    "recurring" => { label: "Всеки месец", description: "Повтарящи се разходи след покупката." }
  }.freeze

  COST_EVENT_LABELS = {
    "first" => "при първото плащане",
    "notarial_transfer" => "при нотариалното прехвърляне",
    "handover" => "при предаването на имота",
    "monthly" => "всеки месец"
  }.freeze

  COMPONENTS = [
    [ "home", "Апартамент / къща" ], [ "garage", "Гараж" ], [ "parking", "Паркомясто" ],
    [ "storage", "Склад" ], [ "other", "Друга част" ]
  ].freeze

  def format_eur(cents, blank: "-")
    return blank if cents.nil?

    sign = cents.to_i.negative? ? "−" : ""
    absolute = cents.to_i.abs
    euros, euro_cents = absolute.divmod(100)
    grouped = euros.to_s.reverse.scan(/.{1,3}/).join(" ").reverse
    "#{sign}#{grouped},#{format('%02d', euro_cents)} €"
  end

  def money_input_value(cents)
    return if cents.nil?

    euros, euro_cents = cents.to_i.divmod(100)
    euro_cents.zero? ? euros.to_s : "#{euros},#{format('%02d', euro_cents)}"
  end

  def calculator_input(path, default = nil)
    @inputs&.dig(*Array(path).map(&:to_s)) || default
  end

  def mortgage_input(path, default = nil)
    @mortgage_inputs&.dig(*Array(path).map(&:to_s)) || default
  end

  def calculator_error(errors, key)
    message = errors.to_h[key.to_s]
    tag.p(message, class: "calculator-field__error", id: "error-#{key.to_s.parameterize}") if message
  end

  def education_entry_path(entry)
    return unless entry

    case entry["kind"]
    when "document" then education_document_path(entry["slug"])
    when "term" then term_path(entry["slug"])
    when "stage" then new_build_stage_path(entry["slug"])
    end
  end

  def education_link(key, label = "Научи повече")
    entry = @education_links&.fetch(key, nil)
    return unless entry && (path = education_entry_path(entry))

    link_to label, path, class: "calculator-help-link", data: {
      controller: "product-event", action: "click->product-event#record", product_event_name_value: "explanation_opened",
      product_event_content_key_value: key, product_event_mode_value: "calculator"
    }
  end

  def cost_input(cost, attribute)
    Array(calculator_input("costs", [])).find { _1["key"] == cost[:key] }&.fetch(attribute.to_s, nil)
  end


  def component_input(key, attribute)
    Array(calculator_input("components", [])).find { _1["key"] == key }&.fetch(attribute.to_s, nil)
  end

  def schedule_event_value(event, key)
    event.to_h[key.to_s]
  end

  def schedule_event_options(events = calculator_input("schedule", []))
    Array(events).each_with_index.map do |event, index|
      row = event.to_h.stringify_keys
      [ row["label"].presence || "Събитие #{index + 1}", row["key"].presence || "event_#{index}" ]
    end
  end

  def calculator_provenance_label(value)
    {
      "verified_statutory_rule" => "Проверено нормативно правило",
      "user_entered_percentage" => "Ръчно въведен процент",
      "user_entered" => "Въведено от теб",
      "user_confirmed_rate" => "Потвърдена от теб ставка",
      "user_confirmed_final_price" => "Потвърдена крайна цена",
      "user_confirmed_exclusive_vat" => "Потвърдена нетна оферта",
      "user_reported" => "Отбелязано от теб",
      "explicit_estimate" => "Изрична приблизителна оценка",
      "unknown" => "Неизвестно"
    }.fetch(value.to_s, "Оценка")
  end
end
