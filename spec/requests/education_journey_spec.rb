require "rails_helper"

RSpec.describe "Education and anonymous buyer journey", type: :request do
  it "serves the hub, a direct Act 15 answer, aliases, canonical content, and mobile navigation" do
    get guide_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Покупката на имот, стъпка по стъпка", "<summary>Меню</summary>")

    get new_build_stage_path("akt-15")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Акт образец 15", "Какво този етап НЕ означава?", "Какво следва?", "Практичен край на статията")
    expect(response.body).not_to include("Твоят избран контекст")

    get new_build_stage_path("akt-14")
    expect(response.body).to include("Апартаментът може още да няма замазки", "Общото търговско название не замества конкретната клауза")

    get education_documents_path, params: { q: "акт16" }
    expect(response.body).to include("„Акт 16“ и въвеждане в експлоатация")

    get education_document_path("akt-15")
    expect(response.body).to include("Какво НЕ установява?", "Пет опорни точки", "Професионален преглед: предстои")

    get term_path("garazh-sreshtu-parkomyasto")
    expect(response.body).to include("Често объркване", "самостоятелен недвижим имот")

    get buying_guide_path
    expect(response.body).to include("Участниците не са взаимозаменяеми", "Инвеститор / възложител", "Кредитор / оценител")

    get "/sitemap.xml"
    expect(response.body).to include(new_build_stage_path("akt-15"), education_document_path("akt-16-vavezhdane-v-eksploatatsiya"))
    expect(response.body).not_to include(my_mesto_path)
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

    expect(response.body).to include("Разглеждаш този етап")
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
    expect(response.body).to include(first_analysis.submitted_identifier, "Последен открит документален етап")

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

    expect(response.body).to include("Преди резервация или капаро", "Конструкция / Акт 14", "Въвеждане в експлоатация")
    expect(response.body).to include("Има по-късен съпоставен запис", "Използвай този контекст", "Запази моя избор", "Не съм сигурен", "Прегледай условията")
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
