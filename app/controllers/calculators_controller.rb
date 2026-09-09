class CalculatorsController < ApplicationController
  before_action :load_education_links, only: %i[index purchase calculate_purchase mortgage calculate_mortgage]

  def index
    ProductEvent.record("calculator_opened", metadata: { calculator: "hub" })
  end

  def purchase
    @inputs = normalized_purchase(params[:example].present? ? example_purchase_inputs : {})
    @result = Calculators::PurchasePlan.new(@inputs).call
    @scenarios = owned_scenarios.limit(4)
    ProductEvent.record("calculator_opened", metadata: { calculator: "purchase" })
  end

  def calculate_purchase
    @inputs = normalized_purchase(calculator_params)
    @result = Calculators::PurchasePlan.new(@inputs).call
    @scenarios = owned_scenarios.limit(4)
    ProductEvent.record("calculation_completed", metadata: { calculator: "purchase", complete: @result["complete"] }) if @result["complete"]
    if turbo_frame_request?
      render partial: "calculators/results", locals: { result: @result, errors: @normalizer.errors }
    else
      render :purchase, status: @normalizer.errors.any? ? :unprocessable_content : :ok
    end
  end

  def mortgage
    raw = params[:example].present? ? { "principal" => "100000", "annual_interest_rate" => "6", "term_years" => "30" } : {}
    @mortgage_inputs = normalized_mortgage(raw)
    @mortgage_result = mortgage_result(@mortgage_inputs)
    ProductEvent.record("calculator_opened", metadata: { calculator: "mortgage" })
  end

  def calculate_mortgage
    @mortgage_inputs = normalized_mortgage(calculator_params)
    @mortgage_result = mortgage_result(@mortgage_inputs)
    if turbo_frame_request?
      render partial: "calculators/mortgage_results", locals: { result: @mortgage_result, errors: @normalizer.errors }
    else
      render :mortgage, status: @normalizer.errors.any? ? :unprocessable_content : :ok
    end
  end

  private

  def calculator_params
    params.fetch(:calculator, {}).permit!
  end

  def normalized_purchase(raw)
    @normalizer = Calculators::InputNormalizer.new
    @normalizer.purchase(raw)
  end

  def normalized_mortgage(raw)
    @normalizer = Calculators::InputNormalizer.new
    @normalizer.mortgage(raw)
  end

  def mortgage_result(inputs)
    Calculators::Mortgage.new(
      principal_cents: inputs["principal_cents"], annual_interest_rate: inputs["annual_interest_rate"],
      term_months: inputs["term_months"], monthly_charges_cents: inputs["monthly_charges_cents"]
    ).call
  end

  def owned_scenarios
    digest = guest_identity_digest
    digest ? BudgetScenario.for_guest(digest).order(updated_at: :desc) : BudgetScenario.none
  end

  def load_education_links
    catalog = Education::Catalog.instance
    @education_links = %w[
      document.preliminary_contract document.reservation_agreement document.tax_assessment
      document.act14 document.act15 document.commissioning term.mortgage
    ].filter_map { |key| catalog.find(key) }.index_by { _1["key"] }
  end

  def example_purchase_inputs
    {
      "property_price" => "300000", "municipality" => "sofia", "financing_mode" => "mortgage",
      "price_vat_treatment" => "final", "loan_principal" => "240000", "annual_interest_rate" => "3,5",
      "term_years" => "30", "starting_cash" => "70000",
      "schedule" => {
        "first" => { "key" => "first", "label" => LocalizedCopy.call("Предварителен договор", "Preliminary contract"), "order" => "1", "amount_type" => "percentage", "percentage" => "10" },
        "second" => { "key" => "second", "label" => LocalizedCopy.call("Акт 14", "Act 14"), "order" => "2", "amount_type" => "percentage", "percentage" => "10" },
        "notarial_transfer" => { "key" => "notarial_transfer", "label" => LocalizedCopy.call("Нотариално прехвърляне", "Notarial transfer"), "order" => "3", "amount_type" => "remaining" }
      },
      "mortgage_availability_event_key" => "notarial_transfer"
    }
  end
end
