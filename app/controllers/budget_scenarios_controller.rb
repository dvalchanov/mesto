class BudgetScenariosController < ApplicationController
  before_action :require_scenario, only: %i[show update destroy duplicate recalculate save]

  def index
    @scenarios = scenario_scope.order(updated_at: :desc)
  end

  def create
    normalizer = Calculators::InputNormalizer.new
    inputs = normalizer.purchase(calculator_params)
    result = Calculators::PurchasePlan.new(inputs).call
    journey = owned_journey(inputs["buyer_journey_id"])
    scenario = scenario_scope.new(
      title: inputs["title"].presence || LocalizedCopy.call("Моята сметка", "My calculation"), currency: "EUR",
      input_schema_version: BudgetScenario::INPUT_SCHEMA_VERSION, validated_inputs: inputs,
      calculation_snapshot: result, engine_version: result["engine_version"], financial_rule_versions: result["rule_versions"],
      calculated_at: Time.current, buyer_journey: journey, property_analysis: journey&.property_analysis
    )
    if normalizer.errors.empty? && scenario.save
      ProductEvent.record("scenario_saved", property_analysis: scenario.property_analysis, metadata: { attached_to_journey: journey.present? })
      redirect_to budget_scenario_path(public_token: scenario), notice: LocalizedCopy.call("Сметката е запазена само в този браузър.", "The calculation has been saved in this browser only.")
    else
      @inputs = inputs
      @result = result
      @normalizer = normalizer
      @scenarios = scenario_scope.limit(4)
      load_education_links
      flash.now[:alert] = normalizer.errors.values.to_sentence.presence || scenario.errors.full_messages.to_sentence
      render "calculators/purchase", status: :unprocessable_content
    end
  end

  def show
    prepare_purchase(@scenario.validated_inputs)
    render "calculators/purchase"
  end

  def update
    if @scenario.update(title: params.dig(:budget_scenario, :title).to_s.strip.first(80))
      redirect_to budget_scenario_path(public_token: @scenario), notice: LocalizedCopy.call("Името на сметката е обновено.", "The calculation name has been updated.")
    else
      redirect_to budget_scenario_path(public_token: @scenario), alert: @scenario.errors.full_messages.to_sentence
    end
  end

  def duplicate
    copy = @scenario.duplicate!
    ProductEvent.record("scenario_saved", property_analysis: copy.property_analysis, metadata: { duplicated: true })
    redirect_to budget_scenario_path(public_token: copy), notice: LocalizedCopy.call("Създадено е копие на сметката.", "A copy of the calculation has been created.")
  end

  def destroy
    @scenario.destroy!
    redirect_to budget_scenarios_path, notice: LocalizedCopy.call("Сметката е изтрита и не може да бъде възстановена.", "The calculation has been deleted and cannot be recovered.")
  end

  def recalculate
    result = Calculators::PurchasePlan.new(@scenario.validated_inputs).call
    @scenario.update!(calculation_snapshot: result, engine_version: result["engine_version"],
      financial_rule_versions: result["rule_versions"], calculated_at: Time.current)
    redirect_to budget_scenario_path(public_token: @scenario), notice: LocalizedCopy.call("Сметката е преизчислена по текущите правила.", "The calculation has been updated using the current rules.")
  end

  def save
    normalizer = Calculators::InputNormalizer.new
    inputs = normalizer.purchase(calculator_params)
    return render_invalid_saved(inputs, normalizer) if normalizer.errors.any?

    result = Calculators::PurchasePlan.new(inputs).call
    journey = owned_journey(inputs["buyer_journey_id"])
    @scenario.update!(
      title: inputs["title"].presence || @scenario.title, validated_inputs: inputs,
      calculation_snapshot: result, engine_version: result["engine_version"],
      financial_rule_versions: result["rule_versions"], calculated_at: Time.current,
      buyer_journey: journey, property_analysis: journey&.property_analysis
    )
    ProductEvent.record("scenario_saved", property_analysis: @scenario.property_analysis, metadata: { updated: true, attached_to_journey: journey.present? })
    redirect_to budget_scenario_path(public_token: @scenario), notice: LocalizedCopy.call("Промените в сметката са запазени.", "Your changes have been saved.")
  end

  def compare
    tokens = Array(params[:scenario_tokens]).first(2)
    scenarios = scenario_scope.where(public_token: tokens).index_by(&:public_token)
    @first = scenarios[tokens[0]]
    @second = scenarios[tokens[1]]
    return redirect_to(budget_scenarios_path, alert: LocalizedCopy.call("Избери точно две свои сметки.", "Select exactly two of your calculations.")) unless @first && @second && @first != @second

    @comparison = Calculators::ScenarioComparison.new(@first.calculation_snapshot, @second.calculation_snapshot).call
    ProductEvent.record("scenario_compared", metadata: { calculator: "purchase" })
  end

  private

  def require_scenario
    @scenario = scenario_scope.find_by!(public_token: params[:public_token])
  end

  def scenario_scope
    BudgetScenario.for_guest(guest_identity_digest(create: action_name == "create"))
  end

  def owned_journey(id)
    return if id.blank?

    guest_journeys.find_by(id:)
  end

  def calculator_params
    params.fetch(:calculator, {}).permit!
  end

  def prepare_purchase(inputs)
    @inputs = inputs.deep_stringify_keys
    @result = @scenario.calculation_snapshot
    @normalizer = Calculators::InputNormalizer.new
    @scenarios = scenario_scope.order(updated_at: :desc).limit(4)
    load_education_links
  end

  def render_invalid_saved(inputs, normalizer)
    @inputs = inputs
    @result = Calculators::PurchasePlan.new(inputs).call
    @normalizer = normalizer
    @scenarios = scenario_scope.order(updated_at: :desc).limit(4)
    load_education_links
    flash.now[:alert] = normalizer.errors.values.to_sentence
    render "calculators/purchase", status: :unprocessable_content
  end

  def load_education_links
    catalog = Education::Catalog.instance
    @education_links = %w[
      document.preliminary_contract document.reservation_agreement document.tax_assessment
      document.act14 document.act15 document.commissioning term.mortgage
    ].filter_map { |key| catalog.find(key) }.index_by { _1["key"] }
  end
end
