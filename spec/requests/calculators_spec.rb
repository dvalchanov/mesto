require "rails_helper"

RSpec.describe "Property-purchase calculators", type: :request do
  let(:complete_params) do
    {
      property_price: "300 000,00", tax_assessment: "250 000,00", municipality: "sofia", transaction_date: "2026-09-06",
      financing_mode: "mortgage", price_vat_treatment: "final", loan_primary_input: "principal",
      loan_principal: "240000", annual_interest_rate: "3,5", term_years: "30", starting_cash: "70000",
      mortgage_availability_event_key: "notarial_transfer", title: "Апартамент А",
      schedule: {
        first: { key: "first", label: "Предварителен договор", order: "1", amount_type: "percentage", percentage: "10", date_precision: "unknown" },
        second: { key: "second", label: "Акт 14", order: "2", amount_type: "percentage", percentage: "10", date_precision: "unknown" },
        closing: { key: "notarial_transfer", label: "Нотариално прехвърляне", order: "3", amount_type: "remaining", date_precision: "unknown" }
      }
    }
  end

  it "serves the free standalone routes with distinct server-rendered content" do
    get calculators_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("От цена на имота до реален план за плащане")

    get purchase_calculator_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Колко ще ти струва покупката", "Без регистрация", "Цена и разходи")
    expect(Nokogiri::HTML5(response.body).at_css('input[name="calculator[property_price]"]')["value"]).to be_blank

    get mortgage_calculator_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Каква би била месечната ти вноска?", "не е ГПР")
  end

  it "calculates progressively over POST and reports invalid Bulgarian input" do
    post calculate_purchase_calculator_path, params: { calculator: complete_params }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("310 292,27 €", "Анюитетна схема", "Изчислено")

    post calculate_purchase_calculator_path, params: { calculator: { property_price: "1.234" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Въведи еднозначно положително число")
  end

  it "uses the same mortgage engine on the focused entry point" do
    post calculate_mortgage_calculator_path, params: { calculator: {
      principal: "100000", annual_interest_rate: "6", term_years: "30"
    } }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("599,55 €", "600,00 €", "Целият погасителен план")
  end

  it "saves, resumes, renames, duplicates, and deletes a guest-owned scenario" do
    expect {
      post budget_scenarios_path, params: { calculator: complete_params }
    }.to change(BudgetScenario, :count).by(1)
    scenario = BudgetScenario.last
    expect(response).to redirect_to(budget_scenario_path(scenario))
    expect(scenario.validated_inputs["property_price_cents"]).to eq(30_000_000)
    expect(scenario.financial_rule_versions).to include("bg.sofia.acquisition_tax" => "2026-01-01.1")

    follow_redirect!
    expect(response.body).to include("Апартамент А", "noindex,nofollow", "Запазена сметка")

    get budget_scenarios_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Запазени сметки", "Апартамент А", "Сравни избраните две", "noindex,nofollow")

    patch budget_scenario_path(scenario), params: { budget_scenario: { title: "Вариант Б" } }
    expect(scenario.reload.title).to eq("Вариант Б")

    expect { post duplicate_budget_scenario_path(scenario) }.to change(BudgetScenario, :count).by(1)
    copy = BudgetScenario.order(:created_at).last
    expect(copy.title).to include("копие")

    post compare_budget_scenarios_path, params: { scenario_tokens: [ scenario.public_token, copy.public_token ] }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Сравнение без победител", "Моделирана лихва")

    expect {
      post save_budget_scenario_path(scenario), params: { calculator: complete_params.merge(property_price: "310000", title: "Обновен вариант") }
    }.not_to change(BudgetScenario, :count)
    expect(scenario.reload).to have_attributes(title: "Обновен вариант")
    expect(scenario.validated_inputs["property_price_cents"]).to eq(31_000_000)

    expect { delete budget_scenario_path(copy) }.to change(BudgetScenario, :count).by(-1)
  end

  it "does not authorize a private scenario by its random URL alone" do
    scenario = BudgetScenario.create!(
      guest_identity_digest: Digest::SHA256.hexdigest("someone-else"), title: "Чужда сметка", currency: "EUR",
      input_schema_version: 1, validated_inputs: {}, calculation_snapshot: {}, engine_version: "1.0.0",
      financial_rule_versions: {}, calculated_at: Time.current
    )

    get budget_scenario_path(scenario)
    expect(response).to have_http_status(:not_found)
  end

  it "allows optional attachment only to a journey owned by the same guest" do
    post buyer_journeys_path, params: { buyer_journey: {
      property_type: "new_build", buyer_stage: "researching", property_presence: "none"
    } }
    journey = BuyerJourney.last

    post budget_scenarios_path, params: { calculator: complete_params.merge(buyer_journey_id: journey.id) }
    expect(BudgetScenario.last.buyer_journey).to eq(journey)

    foreign = create(:buyer_journey)
    post budget_scenarios_path, params: { calculator: complete_params.merge(title: "Без чужда връзка", buyer_journey_id: foreign.id) }
    expect(BudgetScenario.last.buyer_journey).to be_nil
  end

  it "never leaks saved financial assumptions into a shared property report" do
    analysis = create(:property_analysis, status: "partial")
    BudgetScenario.create!(
      guest_identity_digest: Digest::SHA256.hexdigest("private"), property_analysis: analysis,
      title: "PRIVATE-SCENARIO-NAME", currency: "EUR", input_schema_version: 1,
      validated_inputs: { "property_price_cents" => 98_765_432 },
      calculation_snapshot: { "private_note" => "SECRET-CASH-NOTE" }, engine_version: "1.0.0",
      financial_rule_versions: {}, calculated_at: Time.current
    )

    get report_path(analysis)
    expect(response.body).not_to include("PRIVATE-SCENARIO-NAME", "SECRET-CASH-NOTE", "987 654,32")
  end

  it "lists only public calculator pages in the sitemap" do
    get "/sitemap.xml"
    expect(response.body).to include(purchase_calculator_path, mortgage_calculator_path)
    expect(response.body).not_to include("/kalkulator/scenarii")
  end
end
