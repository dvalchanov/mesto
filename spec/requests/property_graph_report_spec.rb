require "rails_helper"

RSpec.describe "Property graph dossier section", type: :request do
  it "renders a precise registered-owner statement, provenance, and the structured fallback" do
    analysis = create(:property_analysis, status: "partial", coverage_status: "partial")
    relevant_at = Time.zone.parse("2026-08-01")
    PropertyRegistry::Importer.new(
      analysis:,
      payload: {
        property_identifier: analysis.submitted_identifier,
        coverage: { complete_history: false, limitation: "Only the supplied electronic period is covered." },
        owners: [
          {
            legal_name: "ПРИМЕР ПРОЕКТ ЕООД", eik: "200370069", current: true,
            source_record_reference: "property-entry-1", source_date: relevant_at
          }
        ]
      },
      source_url: "https://portal.registryagency.bg/property-reference",
      relevant_at:
    ).call
    analysis.source_runs.create!(
      source_key: "property_register", status: "succeeded",
      source_url: "https://portal.registryagency.bg/property-reference", fetched_at: relevant_at, relevant_at:
    )
    analysis.update!(summary: { "property_graph" => PropertyGraph::Presenter.new(analysis:).call })

    get report_path(public_token: analysis)

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML5(response.body)
    section = document.at_css("#ownership[data-controller='property-graph']")
    expect(section).to be_present
    expect(section.text).to include(
      I18n.t("reports.property_graph.title"),
      I18n.t("reports.property_graph.structured_title"),
      I18n.t("reports.property_graph.registered_owner_as_of", owner: "ПРИМЕР ПРОЕКТ ЕООД", date: I18n.l(relevant_at.to_date, format: :short)),
      "property-entry-1",
      "Only the supplied electronic period is covered."
    )
    expect(section.at_css("[data-property-graph-target='canvas']")).to be_present
    expect(section.at_css("[data-property-graph-target='panel']")).to be_present
  end

  it "renders the real AGKK right type and source document without calling it a Property Register owner" do
    analysis = create(:property_analysis, status: "partial", coverage_status: "partial")
    relevant_at = Time.zone.parse("2026-09-02")
    [
      [ analysis.parcel_identifier, "parcel" ],
      [ analysis.building_identifier, "building" ],
      [ analysis.individual_object_identifier, "individual_object" ]
    ].each do |identifier, level|
      CadastralProperty.create!(
        cadastral_identifier: identifier,
        identifier_level: level,
        source_archive_key: "sofia/#{level}.zip",
        source_url: "https://kais.cadastre.bg/bg/OpenData",
        source_relevant_at: relevant_at
      )
    end
    CadastreRight.create!(
      cadastral_identifier: analysis.individual_object_identifier,
      identifier_level: "individual_object",
      right_type: "Право на собственост",
      right_description: "Ид. част 100%",
      holder_type: "Юридическо лице",
      holder_name: "ПРИМЕР ПРОЕКТ ЕООД",
      holder_identifier: "200370069",
      holder_entity_type: "company",
      document_type: "Нотариален акт",
      document_description: "№ 113, том XXXI, дело 9506 от 05.03.2021 г.",
      source_archive_key: "sofia/собственост СОС.zip",
      source_url: "https://kais.cadastre.bg/bg/OpenData",
      source_relevant_at: relevant_at,
      record_fingerprint: Digest::SHA256.hexdigest("rendered-agkk-right")
    )
    PropertyGraph::Builder.new(analysis:).call
    analysis.update!(summary: { "property_graph" => PropertyGraph::Presenter.new(analysis:).call })

    get report_path(public_token: analysis)

    expect(response).to have_http_status(:ok)
    section = Nokogiri::HTML5(response.body).at_css("#ownership")
    expect(section.text).to include(
      "Право на собственост",
      "ПРИМЕР ПРОЕКТ ЕООД",
      "Ид. част 100%",
      "Нотариален акт",
      "№ 113, том XXXI, дело 9506 от 05.03.2021 г.",
      I18n.t("reports.property_graph.limitations.cadastre_rights_snapshot_not_property_register")
    )
    expect(section.text).not_to include(
      I18n.t("reports.property_graph.registered_owner_as_of", owner: "ПРИМЕР ПРОЕКТ ЕООД", date: I18n.l(relevant_at.to_date, format: :short))
    )
  end
end
