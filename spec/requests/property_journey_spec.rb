require "rails_helper"

RSpec.describe "Property report journey", type: :request do
  it "uses the Mesto product identity" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<title>Проверка на имот преди покупка | Mesto</title>")
    expect(response.body).to include('name="description" content="Провери публичните данни за имота, строителството и района. Виж какво още да изискаш и провериш преди покупка."')
    expect(response.body).to include('property="og:site_name" content="Mesto"')
    expect(response.body).to include('/favicon.ico', '/apple-touch-icon.png', pwa_manifest_path)

    header = Nokogiri::HTML5(response.body).at_css(".site-header")
    expect(header.css(".site-nav a").map { |link| link.text.strip }).not_to include(I18n.t("navigation.check_property"))
    expect(header.at_css(".site-actions__cta").text).to include(I18n.t("navigation.check_property"))
  end

  it "serves installable Mesto icons through the web app manifest" do
    get pwa_manifest_path

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(response.parsed_body.fetch("icons")).to contain_exactly(
      hash_including("src" => "/android-chrome-192x192.png", "sizes" => "192x192"),
      hash_including("src" => "/android-chrome-512x512.png", "sizes" => "512x512", "purpose" => "maskable")
    )
  end

  it "loads MapLibre with the module export and stylesheet from the same version" do
    controller = Rails.root.join("app/javascript/controllers/property_map_controller.js").read
    importmap = Rails.root.join("config/importmap.rb").read
    map_partial = Rails.root.join("app/views/reports/_map.html.erb").read

    expect(controller).to include('import * as maplibregl from "maplibre-gl"')
    expect(importmap).to include("maplibre-gl@6.4.1/+esm")
    expect(map_partial).to include("maplibre-gl@6.4.1/dist/maplibre-gl.css")
  end

  it "permanently redirects the legacy knowledge URLs to the canonical library" do
    get guides_path
    expect(response).to redirect_to(guide_path)
    expect(response).to have_http_status(:moved_permanently)

    get documents_path(locale: :en)
    expect(response).to redirect_to(education_documents_path(locale: :en))
    expect(response).to have_http_status(:moved_permanently)

    get glossary_path
    expect(response).to redirect_to(terms_path)
    expect(response).to have_http_status(:moved_permanently)
  end

  it "creates a UUID-token analysis and rejects invalid input" do
    expect {
      post property_analyses_path, params: { cadastral_identifier: " 68134.9998.7777.2.6 " }
    }.to change(PropertyAnalysis, :count).by(1)

    analysis = PropertyAnalysis.last
    expect(response).to redirect_to(report_path(public_token: analysis))
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
    get report_path(public_token: analysis)
    expect(response.body).to include(I18n.t("reports.progress.title"))
    expect(response.body).to include("report-progress__grid-loader")
    expect(response.body).to include('name="robots" content="noindex,nofollow"')

    prepare_complete_sources
    Analysis::Runner.new(analysis, cadastre_provider: successful_cadastre_provider).call
    expect(analysis.reload.status).to eq("ready")
    get report_path(public_token: analysis)
    expect(response.body).to include(
      I18n.t("reports.property_facts.title"),
      I18n.t("reports.findings.title"),
      I18n.t("reports.due_diligence.title"),
      I18n.t("reports.due_diligence.topics.encumbrances.title"),
      I18n.t("reports.locked.cta")
    )
    expect(response.body).not_to include(I18n.t("reports.full.timeline"))

    post report_orders_path(public_token: analysis), params: { order: { email: "buyer@example.com", amount_cents: 1 } }
    order = analysis.orders.last
    expect(order.amount_cents).to eq(2_490)
    expect(response).to redirect_to(checkout_path(public_token: order))

    post fake_checkout_succeed_path(public_token: order)
    expect(response).to redirect_to(checkout_success_path(public_token: order))
    expect(order.reload.status).to eq("paid")

    post fake_checkout_succeed_path(public_token: order)
    expect(ProductEvent.where(order:, name: "fake_payment_succeeded").count).to eq(1)

    get report_path(public_token: analysis)
    expect(response.body).to include(I18n.t("reports.full.timeline"))
  end

  it "keeps reports locked after fake failure and cancellation" do
    analysis = create(:property_analysis, status: "partial", summary: { "paid_content_available" => true })
    failed = Payments::FakeGateway.new.create_order(property_analysis: analysis, email: "fail@example.com")
    cancelled = Payments::FakeGateway.new.create_order(property_analysis: analysis, email: "cancel@example.com")

    post fake_checkout_fail_path(public_token: failed)
    expect(response).to redirect_to(checkout_path(public_token: failed, outcome: "failed"))
    follow_redirect!
    expect(response.body).to include(I18n.t("checkout.failed"))

    post fake_checkout_cancel_path(public_token: cancelled)
    expect(response).to redirect_to(checkout_path(public_token: cancelled, outcome: "cancelled"))
    follow_redirect!
    expect(response.body).to include(I18n.t("checkout.cancelled"))
    expect(analysis.reload).not_to be_full_report_unlocked
  end

  it "does not offer checkout for non-Sofia or no-data reports" do
    analysis = create(:property_analysis, status: "partial", summary: { "outside_sofia" => true, "paid_content_available" => false })

    get report_checkout_path(public_token: analysis)

    expect(response).to redirect_to(report_path(public_token: analysis))
  end

  it "does not offer checkout when any required check is incomplete" do
    analysis = create(
      :property_analysis,
      status: "partial",
      coverage_status: "partial",
      summary: { "paid_content_available" => true }
    )

    get report_checkout_path(public_token: analysis)

    expect(response).to redirect_to(report_path(public_token: analysis))
    follow_redirect!
    expect(response.body).to include(I18n.t("checkout.unavailable"))
    expect(response.body).to include(I18n.t("reports.paid_unavailable.no_charge"))
    expect(response.body).not_to include(I18n.t("reports.locked.cta"))
  end

  it "does not label contract-only registry checks as mandatory blockers" do
    analysis = create(:property_analysis, status: "partial", coverage_status: "partial")
    analysis.source_runs.create!(
      source_key: "cadastre", status: "unavailable",
      error_message: "Official district archive is not published"
    )
    %w[property_register commercial_register].each do |source_key|
      analysis.source_runs.create!(source_key:, status: "unavailable", error_message: "Contract required")
    end

    get report_path(public_token: analysis)

    panel = Nokogiri::HTML5(response.body).at_css('[data-testid="paid-report-unavailable"]').text
    expect(panel).to include(I18n.t("reports.sources.names.cadastre"))
    expect(panel).not_to include(
      I18n.t("reports.sources.names.property_register"),
      I18n.t("reports.sources.names.commercial_register")
    )
  end

  it "distinguishes restricted, contract-only, and inapplicable enrichment from failed checks" do
    analysis = create(:property_analysis, status: "partial", coverage_status: "partial")
    analysis.source_runs.create!(
      source_key: "property_register", status: "unavailable",
      error_class: "PublicRegistry::AutomationUnavailable",
      request_metadata: { access: "provider_contract" }
    )
    analysis.source_runs.create!(
      source_key: "commercial_register", status: "unavailable",
      error_class: "PublicRegistry::AutomationUnavailable",
      request_metadata: { access: "provider_contract" }
    )
    analysis.source_runs.create!(
      source_key: "vies", status: "unavailable",
      error_class: "PublicRegistry::NoReliableIdentifier",
      request_metadata: { access: "not_attempted_without_eik" }
    )

    get report_path(public_token: analysis)

    sources = Nokogiri::HTML5(response.body).css("details").find do |details|
      details.text.include?(I18n.t("reports.sources.title"))
    end.text
    expect(sources).to include(
      I18n.t("reports.sources.results.restricted_access"),
      I18n.t("reports.sources.results.contract_required"),
      I18n.t("reports.sources.results.not_applicable")
    )
    expect(sources).not_to include(I18n.t("reports.sources.results.failed"))
  end

  it "hides and rejects checkout while the production kill switch is off" do
    analysis = create(
      :property_analysis,
      status: "ready",
      coverage_status: "complete",
      summary: { "paid_content_available" => true }
    )
    order = Payments::FakeGateway.new.create_order(property_analysis: analysis, email: "buyer@example.com")
    previous_value = Rails.application.config.x.checkout_enabled

    begin
      Rails.application.config.x.checkout_enabled = false

      get report_path(public_token: analysis)
      expect(response.body).to include(I18n.t("checkout.disabled"))
      expect(response.body).not_to include(I18n.t("reports.locked.cta"))

      expect {
        post report_orders_path(public_token: analysis), params: { order: { email: "another@example.com" } }
      }.not_to change(Order, :count)
      expect(response).to redirect_to(report_path(public_token: analysis))

      get checkout_path(public_token: order)
      expect(response).to redirect_to(report_path(public_token: analysis))
    ensure
      Rails.application.config.x.checkout_enabled = previous_value
    end
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

    get report_path(public_token: analysis)

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

    get report_path(public_token: analysis)

    expect(response.body).to include("Малинова долина")
    expect(response.body).not_to include(
      "Gaz 17",
      "Adm rzp",
      I18n.t("reports.full.amenities"),
      I18n.t("reports.full.environment"),
      I18n.t("reports.full.not_calculated")
    )
  end

  it "does not present historical amenity zeroes as current counts" do
    point = RGeo::Geographic.spherical_factory(srid: 4326).point(23.3460, 42.6394)
    analysis = create(
      :property_analysis,
      status: "ready",
      centroid: point,
      completed_at: Time.zone.parse("2026-09-02"),
      location_precision: "cadastral_geometry",
      metrics: {
        "amenities" => {
          "availability" => { "schools" => true, "kindergartens" => true },
          "schools" => { "1000" => 0 },
          "kindergartens" => { "1000" => 0 },
          "datasets" => {
            "schools" => { "relevant_at" => "2018-08-08" },
            "kindergartens" => { "relevant_at" => "2018-08-08" }
          }
        },
        "environment" => { "available" => false }
      }
    )

    get report_path(public_token: analysis)

    card = Nokogiri::HTML5(response.body).at_css('[data-testid="amenity-kindergartens"]')
    expect(card.at_css("p").text.strip).to eq("-")
    expect(card.text).to include("Данни към 08.08.2018", "0 записа", "Това не е текущ брой")
    expect(card["class"]).to include("border-slate-200", "bg-slate-50")
    expect(response.body).to include(I18n.t("reports.neighborhood.dataset_scope_note"))

    order = Payments::FakeGateway.new.create_order(property_analysis: analysis, email: "buyer@example.com")
    Payments::FakeGateway.new.succeed(order)
    get report_path(public_token: analysis)

    expect(response.body).to include(I18n.t("reports.full.historical_amenities", date: "Данни към 08.08.2018"))
    expect(response.body).not_to include(I18n.t("reports.full.amenity_count", count: 0, radius: 1000))
  end

  it "shows current nearby places and reserves the detailed list for the full report" do
    point = RGeo::Geographic.spherical_factory(srid: 4326).point(23.3460262, 42.6394047)
    analysis = create(
      :property_analysis,
      status: "ready",
      centroid: point,
      completed_at: Time.zone.parse("2026-09-02"),
      location_precision: "cadastral_geometry",
      coverage_profile_key: DataCoverage.profile.key
    )
    import = DataSources::OpenStreetMap::DatasetSynchronizer.new.sync
    dataset = import.spatial_dataset
    analysis.source_runs.create!(
      source_key: "openstreetmap_nearby_amenities",
      status: "succeeded",
      parsed_payload: { "feature_count" => dataset.spatial_features.count, "coverage_status" => "complete" },
      source_url: dataset.source_url,
      fetched_at: dataset.last_imported_at,
      relevant_at: dataset.relevant_at
    )
    analysis.update!(metrics: Analysis::MetricsBuilder.new(analysis:).call)

    get report_path(public_token: analysis)

    card = Nokogiri::HTML5(response.body).at_css('[data-testid="amenity-kindergartens"]')
    expect(card.at_css("p").text.strip).to eq("2")
    expect(card.text).to include("ДГ №190", "303 м")
    expect(response.body).to include(I18n.t("reports.neighborhood.openstreetmap_scope_note"))
    expect(response.body).not_to include(I18n.t("reports.neighborhood.acts"), I18n.t("reports.neighborhood.flood"))

    order = Payments::FakeGateway.new.create_order(property_analysis: analysis, email: "buyer@example.com")
    Payments::FakeGateway.new.succeed(order)
    get report_path(public_token: analysis)

    expect(response.body).to include(
      I18n.t("reports.full.mapped_places"),
      "ДГ №190",
      "https://www.openstreetmap.org/way/1256636075"
    )
  end

  def successful_cadastre_provider
    prepare_cadastre_rights_snapshot
    point = RGeo::Geographic.spherical_factory(srid: 4326).point(23.3205, 42.6905)
    factory = RGeo::Cartesian.preferred_factory(srid: 4326)
    ring = factory.linear_ring([
      factory.point(23.319, 42.689), factory.point(23.322, 42.689),
      factory.point(23.322, 42.692), factory.point(23.319, 42.692),
      factory.point(23.319, 42.689)
    ])
    parcel = factory.multi_polygon([ factory.polygon(ring) ])
    result = DataSources::Result.success(
      data: {
        "analysis_point" => point,
        "parcel_geometry" => parcel,
        "precision" => "cadastral_geometry",
        "geometry_bases" => {
          "amenity_proximity" => "selected_building_representative_point",
          "parcel_planning" => "parcel_polygon"
        }
      },
      source_url: "https://kais.cadastre.bg/bg/OpenData",
      relevant_at: Time.zone.parse("2026-08-05")
    )
    instance_double(Cadastre::Provider, locate: result)
  end

  def prepare_cadastre_rights_snapshot
    profile = DataCoverage.profile
    source_url = "https://kais.cadastre.bg/bg/OpenData"
    relevant_at = Time.zone.parse("2026-08-05")
    identifiers = {
      "parcel" => "68134.1000.2000",
      "building" => "68134.1000.2000.1",
      "individual_object" => "68134.1000.2000.1.5"
    }
    archive_names = DataSources::CadastreOpenData::DistrictSynchronizer::ARCHIVE_NAMES
    identifiers.each do |level, identifier|
      CadastralProperty.create!(
        cadastral_identifier: identifier,
        identifier_level: level,
        source_archive_key: "test/#{level}.zip",
        source_url:,
        source_relevant_at: relevant_at
      )
      rights_key = "test/#{archive_names.fetch("#{level}_rights".to_sym)}"
      CadastreImport.create!(
        source_archive_key: rights_key,
        source_url:,
        source_checksum: Digest::SHA256.hexdigest(rights_key),
        importer_version: DataSources::CadastreOpenData::OwnershipArchiveImporter::IMPORTER_VERSION,
        scope_digest: profile.scope_digest,
        coverage_profile_key: profile.key,
        status: "succeeded",
        relevant_at:,
        completed_at: Time.current
      )
    end
  end

  def prepare_complete_sources
    profile = DataCoverage.profile
    DataSources::Sofiaplan::DatasetSynchronizer.new(coverage_profile: profile).sync
    DataSources::ArcGis::DatasetSynchronizer.new(coverage_profile: profile).sync
    DataSources::OpenStreetMap::DatasetSynchronizer.new(coverage_profile: profile).sync
      .spatial_dataset.update!(coverage_status: "complete")
    DataSources.config.dig("nag", "registers").each_key do |key|
      SourceSnapshot.create!(
        source_key: "nag_#{key}",
        provider: "NAG",
        source_url: "https://nag.sofia.bg/#{key}",
        coverage_profile_key: profile.key,
        status: "succeeded",
        coverage_status: "complete",
        fetched_at: Time.current,
        permission_status: "approved",
        metadata: { "searched_identifiers" => analysis_identifiers }
      )
    end
  end


  def analysis_identifiers
    %w[68134.1000.2000 68134.1000.2000.1 68134.1000.2000.1.5]
  end
end
