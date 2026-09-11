require "rails_helper"

RSpec.describe "Mesto journey", type: :system do
  before { driven_by :rack_test }
  before { PropertyAnalysis.where(submitted_identifier: "68134.1000.2000.1.5").destroy_all }

  it "searches, previews, checks out, pays, and revisits an unlocked report" do
    visit root_path
    expect(page).to have_css("h1", text: I18n.t("home.headline"))
    click_link I18n.t("home.search.by_identifier")
    fill_in I18n.t("home.search.label"), with: "68134.1000.2000.1.5"
    click_button I18n.t("home.search.submit")

    analysis = PropertyAnalysis.last
    expect(page).to have_text(I18n.t("reports.progress.title"))
    prepare_complete_sources
    Analysis::Runner.new(analysis, cadastre_provider: successful_cadastre_provider).call
    expect(analysis.reload.status).to eq("ready")
    visit report_path(public_token: analysis)
    expect(page).to have_text(I18n.t("reports.locked.cta"))
    expect(page).not_to have_text(I18n.t("reports.full.timeline"))

    click_link I18n.t("reports.locked.cta")
    fill_in I18n.t("checkout.email"), with: "buyer@example.com"
    click_button I18n.t("checkout.submit")
    click_button I18n.t("checkout.success_action")
    expect(page).to have_text(I18n.t("checkout.success_title"))
    click_link I18n.t("checkout.back_to_report")

    expect(page).to have_text(I18n.t("reports.full.timeline"))
    visit report_path(public_token: analysis)
    expect(page).to have_text(I18n.t("reports.full.timeline"))
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
        metadata: {
          "searched_identifiers" => %w[68134.1000.2000 68134.1000.2000.1 68134.1000.2000.1.5]
        }
      )
    end
  end
end
