require "rails_helper"

RSpec.describe "Property report journey", type: :request do
  it "uses the Mesto product identity" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<title>Mesto —")
    expect(response.body).to include('property="og:site_name" content="Mesto"')
  end

  it "serves the bilingual buyer knowledge library" do
    get guides_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("knowledge.guides.title", locale: :bg))

    get documents_path, params: { locale: :en }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("knowledge.documents.title", locale: :en))

    get glossary_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("knowledge.glossary.title", locale: :en))
  end

  it "creates a UUID-token analysis and rejects invalid input" do
    expect {
      post property_analyses_path, params: { cadastral_identifier: " 68134.9998.7777.2.6 " }
    }.to change(PropertyAnalysis, :count).by(1)

    analysis = PropertyAnalysis.last
    expect(response).to redirect_to(report_path(analysis))
    expect(response.location).not_to include("/#{analysis.id}")
    expect(analysis.public_token).to match(/\A[0-9a-f-]{36}\z/)
    expect(AnalyzePropertyJob).to have_been_enqueued.with(analysis.id)

    expect {
      post property_analyses_path, params: { cadastral_identifier: "not-an-identifier" }
    }.not_to change(PropertyAnalysis, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("home.search.invalid"))
  end

  it "renders progress, free preview, locked details, and successful unlock" do
    analysis = create(:property_analysis)
    get report_path(analysis)
    expect(response.body).to include(I18n.t("reports.progress.title"))

    DataSources::Sofiaplan::DatasetSynchronizer.new.sync
    Analysis::Runner.new(analysis).call
    get report_path(analysis)
    expect(response.body).to include(I18n.t("reports.property_facts.title"), I18n.t("reports.findings.title"), I18n.t("reports.locked.cta"))
    expect(response.body).not_to include(I18n.t("reports.full.timeline"))

    post report_orders_path(analysis), params: { order: { email: "buyer@example.com", amount_cents: 1 } }
    order = analysis.orders.last
    expect(order.amount_cents).to eq(2_490)
    expect(response).to redirect_to(checkout_path(order))

    post fake_checkout_succeed_path(order)
    expect(response).to redirect_to(checkout_success_path(order))
    expect(order.reload.status).to eq("paid")

    post fake_checkout_succeed_path(order)
    expect(ProductEvent.where(order:, name: "fake_payment_succeeded").count).to eq(1)

    get report_path(analysis)
    expect(response.body).to include(I18n.t("reports.full.timeline"))
  end

  it "keeps reports locked after fake failure and cancellation" do
    analysis = create(:property_analysis, status: "partial", summary: { "paid_content_available" => true })
    failed = Payments::FakeGateway.new.create_order(property_analysis: analysis, email: "fail@example.com")
    cancelled = Payments::FakeGateway.new.create_order(property_analysis: analysis, email: "cancel@example.com")

    post fake_checkout_fail_path(failed)
    expect(response).to redirect_to(checkout_path(failed, outcome: "failed"))
    follow_redirect!
    expect(response.body).to include(I18n.t("checkout.failed"))

    post fake_checkout_cancel_path(cancelled)
    expect(response).to redirect_to(checkout_path(cancelled, outcome: "cancelled"))
    follow_redirect!
    expect(response.body).to include(I18n.t("checkout.cancelled"))
    expect(analysis.reload).not_to be_full_report_unlocked
  end

  it "does not offer checkout for non-Sofia or no-data reports" do
    analysis = create(:property_analysis, status: "partial", summary: { "outside_sofia" => true, "paid_content_available" => false })

    get report_checkout_path(analysis)

    expect(response).to redirect_to(report_path(analysis))
  end
end
