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
    expect(response.body).to include("report-progress__grid-loader")

    Analysis::Runner.new(analysis, cadastre_provider: successful_cadastre_provider).call
    expect(analysis.reload.status).to eq("ready")
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

  it "does not offer checkout when any required check is incomplete" do
    analysis = create(
      :property_analysis,
      status: "partial",
      coverage_status: "partial",
      summary: { "paid_content_available" => true }
    )

    get report_checkout_path(analysis)

    expect(response).to redirect_to(report_path(analysis))
    follow_redirect!
    expect(response.body).to include(I18n.t("checkout.unavailable"))
    expect(response.body).to include(I18n.t("reports.paid_unavailable.no_charge"))
    expect(response.body).not_to include(I18n.t("reports.locked.cta"))
  end

  it "separates a blocking location failure from spatial checks skipped because of it" do
    analysis = create(:property_analysis, status: "partial", coverage_status: "good")
    analysis.source_runs.create!(
      source_key: "cadastre", status: "unavailable",
      error_class: "DataSources::CadastreOpenData::ArchiveUnavailable",
      error_message: "Official district archive is not published"
    )
    analysis.source_runs.create!(
      source_key: "arcgis_functional_zoning", status: "unavailable",
      error_message: "A reliable location is required"
    )

    get report_path(analysis)

    panel = Nokogiri::HTML5(response.body).at_css('[data-testid="paid-report-unavailable"]').text
    expect(panel).to include(
      I18n.t("reports.sources.names.cadastre"),
      I18n.t("reports.sources.issues.cadastre_archive_unavailable"),
      I18n.t("reports.paid_unavailable.location_dependencies", count: 1)
    )
    expect(panel).not_to include(I18n.t("reports.sources.names.arcgis_functional_zoning"))
  end

  it "explains an already-unlocked partial report without raw planning fields or false zeroes" do
    analysis = create(
      :property_analysis,
      status: "partial",
      coverage_status: "partial",
      metrics: {
        "amenities" => { "availability" => {} },
        "environment" => { "available" => false }
      },
      summary: {
        "paid_content_available" => false,
        "planning" => [
          {
            "source_key" => "arcgis_functional_zoning",
            "features" => [
              {
                "properties" => {
                  "RegName" => "Малинова долина", "Rajon" => "Студентска",
                  "Preobl_et" => "от 4 до 6 етажа", "Gaz_17" => 123, "Adm_rzp" => 456
                }
              }
            ]
          }
        ]
      }
    )
    order = Payments::FakeGateway.new.create_order(property_analysis: analysis, email: "buyer@example.com")
    Payments::FakeGateway.new.succeed(order)

    get report_path(analysis)

    expect(response.body).to include("Малинова долина", I18n.t("reports.full.not_calculated"))
    expect(response.body).not_to include("Gaz 17", "Adm rzp")
  end

  def successful_cadastre_provider
    point = RGeo::Geographic.spherical_factory(srid: 4326).point(23.3205, 42.6905)
    result = DataSources::Result.success(
      data: { "centroid" => point, "precision" => "cadastral_geometry" },
      source_url: "https://kais.cadastre.bg/bg/OpenData",
      relevant_at: Time.zone.parse("2026-08-05")
    )
    instance_double(Cadastre::Provider, locate: result)
  end
end
