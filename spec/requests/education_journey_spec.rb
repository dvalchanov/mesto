require "rails_helper"

RSpec.describe "Education and anonymous buyer journey", type: :request do
  it "serves the hub, a direct Act 15 answer, aliases, canonical content, and mobile navigation" do
    get guide_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      "Подготви покупката си стъпка по стъпка", "<summary>Меню</summary>",
      "Сравняване на конкретни имоти", "Първите месеци като собственик", "Намери ясно обяснение"
    )

    get new_build_stage_path("akt-15")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Акт образец 15", "Какво не означава този етап?", "Какво обикновено следва?", "Преди да продължиш")
    expect(response.body).not_to include("Твоят избран контекст")

    get new_build_stage_path("akt-14")
    expect(response.body).to include("Апартаментът може още да няма замазки", "Общото търговско название не замества конкретната клауза")

    get education_documents_path, params: { q: "акт16" }
    expect(response.body).to include("„Акт 16“ и въвеждане в експлоатация", "Строителни етапи")

    get education_documents_path, params: { q: "сравнявам варианти" }
    expect(response.body).to include("Път на купувача", "Сравняване на конкретни имоти", "#shortlisting")

    get education_documents_path, params: { q: "дефекти" }
    defect_results = Nokogiri::HTML(response.body)
    expect(defect_results.css('a[href="/termini/yavni-skriti-defekti"]').size).to eq(1)

    get education_documents_path
    expect(response.body).to include(
      "Планиране и строителство", "Имот и собственост", "Договори и финансиране",
      "Предаване и управление", "Удостоверение за степен „груб строеж“", "Пълномощно за имотна сделка"
    )

    get education_document_path("odobren-investitsionen-proekt")
    expect(response.body).to include("Какво можеш да установиш от него?", "Провери тези подробности", "договорните приложения")

    get terms_path
    expect(response.body).to include(
      "Идентичност на имота", "Собственост и ползване", "Сделка и вписвания",
      "Ново строителство", "Предаване и експлоатация", "Задатък, капаро и резервационна такса"
    )

    get terms_path, params: { q: "възбрана" }
    expect(response.body).to include("Намерени резултати за „възбрана“:", "Възбрана")

    get education_document_path("akt-15")
    expect(response.body).to include("Какво не установява?", "Провери тези подробности", "все още не е прегледано от специалист")

    get term_path("garazh-sreshtu-parkomyasto")
    expect(response.body).to include("Често объркване", "самостоятелен недвижим имот")

    get buying_guide_path
    buyer_page = Nokogiri::HTML(response.body)
    expect(response.body).to include(
      "Всеки участник има различна роля", "Инвеститор / възложител", "Кредитор и оценител",
      "Провери, преди да продължиш", "Свързани документи, термини и етапи", "Избери друга ситуация",
      "Официални източници и редакционен статус", "все още не е прегледано от специалист"
    )
    expect(buyer_page.css(".buyer-guide").size).to eq(11)
    expect(buyer_page.at_css("#shortlisting")).to be_present
    expect(buyer_page.at_css("#owner")).to be_present
    expect(buyer_page.at_css('a[href="#unknown"]')).to be_nil

    get "/sitemap.xml"
    expect(response.body).to include(new_build_stage_path("akt-15"), education_document_path("akt-16-vavezhdane-v-eksploatatsiya"))
    expect(response.body).not_to include(my_mesto_path)
  end

  it "switches the public buyer experience to English" do
    paths = [
      root_path, guides_path, documents_path, glossary_path,
      guide_path, buying_guide_path, new_build_guide_path, new_build_stage_path("akt-15"),
      education_documents_path, education_document_path("predvaritelen-dogovor"),
      terms_path, term_path("vazbrana"), calculators_path, purchase_calculator_path,
      mortgage_calculator_path, budget_scenarios_path, my_mesto_path
    ]

    paths.each do |path|
      get path, params: { locale: "en" }

      expect(response).to have_http_status(:ok), "Expected #{path} to render successfully"
      expect(response.body).to include('<html lang="en">')
      expect(Nokogiri::HTML5(response.body).at_css("body").text).not_to match(/[А-Яа-я]/), "Untranslated copy on #{path}"
    end
  end

  it "records allowlisted education transitions without raw property or financial metadata" do
    expect {
      get root_path, params: { education_entry: "guide" }
    }.to change { ProductEvent.where(name: "education_to_property_check").count }.by(1)

    expect {
      post product_events_path, params: { name: "contextual_explanation_opened", content_key: "document.act15", mode: "property_connected", cadastral_identifier: "not-recorded" }
    }.to change { ProductEvent.where(name: "contextual_explanation_opened").count }.by(1)
    expect(ProductEvent.last.metadata).to eq("content_key" => "document.act15", "mode" => "property_connected")

    post product_events_path, params: { name: "arbitrary_event" }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "creates and resumes a useful plan without property, account, payment, or external call" do
    analysis_count = PropertyAnalysis.count
    expect {
      post buyer_journeys_path, params: { buyer_journey: { property_type: "new_build", buyer_stage: "before_deposit", property_presence: "none" } }
    }.to change(BuyerJourney, :count).by(1)
    expect(PropertyAnalysis.count).to eq(analysis_count)

    journey = BuyerJourney.last
    expect(response).to redirect_to(my_mesto_path)
    expect(journey.guest_identity_digest).to be_present

    get my_mesto_path
    expect(response.body).to include("Твоята подготовка за покупка", "Преди резервация или капаро", "Прегледай условията", "Разбери тези понятия")
    expect(response.body).to include(
      'href="/narachnik/pokupka-na-imot#before_deposit"',
      'href="/narachnik/novo-stroitelstvo/razreshenie-za-stroezh"',
      'href="/dokumenti/notarialen-akt"'
    )
    expect(response.body).to include('name="robots" content="noindex,nofollow"')

    patch buyer_journey_progress_path, params: { item_kind: "task", item_key: "task.review_deposit_terms", status: "done", content_version: 1 }
    expect(journey.journey_item_progresses.find_by(item_key: "task.review_deposit_terms").status).to eq("done")
    patch buyer_journey_progress_path, params: { item_kind: "task", item_key: "task.review_deposit_terms", status: "done", content_version: 2 }
    expect(journey.journey_item_progresses.where(item_key: "task.review_deposit_terms").count).to eq(1)
    expect(journey.journey_item_progresses.find_by(item_key: "task.review_deposit_terms").content_version).to eq(2)
    get my_mesto_path
    expect(response.body).to include("1 от")
  end

  it "does not change declared context merely because a future stage is browsed" do
    post buyer_journeys_path, params: { buyer_journey: { property_type: "new_build", buyer_stage: "researching", property_presence: "none" } }
    journey = BuyerJourney.last

    get new_build_stage_path("vavezhdane-v-eksploatatsiya"), params: { buyer_stage: "before_notarial_transfer" }

    expect(response.body).to include("Текуща тема", "Този избор променя само съвета на страницата")
    expect(journey.reload.buyer_stage).to eq("researching")
  end

  it "attaches a property later, retains progress, and creates a separate case for another report" do
    post buyer_journeys_path, params: { buyer_journey: { property_type: "new_build", buyer_stage: "researching", property_presence: "none" } }
    original = BuyerJourney.last
    patch buyer_journey_progress_path, params: { item_kind: "task", item_key: "task.define_needs", status: "done", content_version: 1 }
    patch buyer_journey_progress_path, params: { item_kind: "task", item_key: "task.compare_identity", status: "done", content_version: 1 }
    first_analysis = create(:property_analysis, status: "ready", completed_at: Time.current)

    post attach_report_to_journey_path(first_analysis)

    expect(original.reload.property_analysis).to eq(first_analysis)
    expect(original.journey_item_progresses.find_by(item_key: "task.define_needs").status).to eq("done")
    get my_mesto_path
    expect(response.body).to include(first_analysis.submitted_identifier, "Етап според последния открит документ")

    second_analysis = create(:property_analysis, submitted_identifier: "68134.1000.2000.2.6", building_identifier: "68134.1000.2000.2", individual_object_identifier: "68134.1000.2000.2.6", status: "ready", completed_at: Time.current)
    expect { post attach_report_to_journey_path(second_analysis) }.to change(BuyerJourney, :count).by(1)
    expect(BuyerJourney.order(:created_at).last.journey_item_progresses.find_by(item_key: "task.define_needs").status).to eq("done")
    expect(BuyerJourney.order(:created_at).last.journey_item_progresses.find_by(item_key: "task.compare_identity")).to be_nil
    expect(BuyerJourney.order(:created_at).last.user_reported_building_stage).to be_nil
    expect(BuyerJourney.order(:created_at).last.label).to be_nil
    expect(original.reload.property_analysis).to eq(first_analysis)
  end

  it "keeps an early buyer stage separate from stronger later building evidence" do
    post buyer_journeys_path, params: { buyer_journey: { property_type: "new_build", buyer_stage: "before_deposit", user_reported_building_stage: "act14", property_presence: "none" } }
    journey = BuyerJourney.last
    analysis = create(:property_analysis, status: "ready", completed_at: Time.current)
    act = create(:administrative_act, registry_kind: "occupancy_certificates", issued_on: Date.current, title: "Удостоверение за въвеждане в експлоатация")
    act.administrative_act_references.create!(cadastral_identifier: analysis.building_identifier, reference_level: "building", match_basis: "document")
    post attach_report_to_journey_path(analysis)

    get my_mesto_path

    expect(response.body).to include("Преди резервация или капаро", "Конструкция и Акт 14", "Въвеждане в експлоатация")
    expect(response.body).to include("Открихме документ за по-късен етап", "Виж документа", "Запази моя избор", "Не съм сигурен", "Прегледай условията")
    expect(journey.reload.buyer_stage).to eq("before_deposit")
    expect(journey.user_reported_building_stage).to eq("act14")
  end

  it "keeps education useful when every connected source is unavailable" do
    post buyer_journeys_path, params: { buyer_journey: { property_type: "new_build", buyer_stage: "waiting_or_payment", property_presence: "none" } }
    analysis = create(:property_analysis, status: "partial", completed_at: Time.current)
    analysis.source_runs.create!(source_key: "nag_building_permits", status: "unavailable", error_message: "timeout")
    post attach_report_to_journey_path(analysis)

    get my_mesto_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Провери клаузата преди следващо плащане", "не доказва, че такъв не съществува")
    expect(response.body).not_to include("официално потвърден")
  end

  it "adds explicit accessible explanations to visible report records without exposing locked records" do
    analysis = create(:property_analysis, status: "ready", completed_at: Time.current)
    visible = create(:administrative_act, registry_kind: "building_permits", issued_on: Date.current, title: "Видимо разрешение")
    visible.administrative_act_references.create!(cadastral_identifier: analysis.building_identifier, reference_level: "building")
    second = create(:administrative_act, registry_kind: "design_visas", issued_on: 1.day.ago, title: "Видима виза")
    second.administrative_act_references.create!(cadastral_identifier: analysis.building_identifier, reference_level: "building")
    hidden = create(:administrative_act, registry_kind: "occupancy_certificates", issued_on: 1.year.ago, title: "СКРИТ ЗАПИС 991")
    hidden.administrative_act_references.create!(cadastral_identifier: analysis.building_identifier, reference_level: "building")

    get report_path(analysis)

    expect(response.body).to include("Разбери този вид документ", "Какво означава?", education_document_path("razreshenie-za-stroezh"))
    expect(response.body).not_to include("СКРИТ ЗАПИС 991")
  end

  it "authorizes journey state by guest cookie and keeps it out of shared reports" do
    post buyer_journeys_path, params: { buyer_journey: { property_type: "new_build", buyer_stage: "waiting_or_payment", financing_context: "mortgage", label: "Личен вариант", property_presence: "none" } }
    private_journey = BuyerJourney.last
    analysis = create(:property_analysis, status: "ready", completed_at: Time.current)
    post attach_report_to_journey_path(analysis)

    stranger = ActionDispatch::Integration::Session.new(Rails.application)
    stranger.get my_mesto_path, params: { journey: private_journey.public_token }
    expect(stranger.response.body).not_to include("Личен вариант")

    stranger.patch buyer_journey_path, params: { journey: private_journey.public_token, buyer_journey: { buyer_stage: "owner" } }
    expect(stranger.response).to have_http_status(:not_found)
    expect(private_journey.reload.buyer_stage).to eq("waiting_or_payment")

    stranger.get report_path(analysis)
    expect(stranger.response.body).not_to include("Личен вариант", "Ипотечно финансиране", "Чакам следващ етап или плащане")
  end
end
