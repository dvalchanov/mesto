require "rails_helper"

RSpec.describe "Property graph dossier", type: :system do
  let(:identifier) { "68134.1607.1254.1.5" }

  before { create_cadastral_hierarchy }

  it "runs the complete synthetic registry flow from home-page submission and remains usable on mobile" do
    page.current_window.resize_to(1_400, 1_000)
    visit root_path
    fill_in I18n.t("home.search.label"), with: identifier
    click_button I18n.t("home.search.submit")

    expect(page).to have_text(I18n.t("reports.progress.title"))
    analysis = PropertyAnalysis.find_by!(submitted_identifier: identifier)

    Analysis::Runner.new(
      analysis,
      property_registry_provider: PropertyRegistry::DemoProvider.new,
      commercial_registry_provider: CommercialRegistry::DemoProvider.new
    ).call
    registry_runs = analysis.current_source_runs.where(source_key: %w[property_register commercial_register])
    expect(registry_runs.pluck(:status)).to contain_exactly("succeeded", "succeeded")
    expect(registry_runs.pluck(:request_metadata)).to all(include("demo_data" => true))
    expect(
      analysis.property_graph_relationships.where(source_key: %w[property_register commercial_register])
        .distinct.pluck(:claim_origin)
    ).to eq([ "synthetic_demo" ])
    visit report_path(public_token: analysis)

    expect(page).to have_css(".report-disclosure-toggle", text: "+", count: 2)
    disclosure_styles = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".report-disclosure")].map((disclosure) => {
        const summary = disclosure.querySelector(".report-disclosure__summary")
        const heading = summary.querySelector("h2")
        const disclosureStyle = getComputedStyle(disclosure)
        const summaryStyle = getComputedStyle(summary)
        const headingStyle = getComputedStyle(heading)

        return {
          backgroundColor: disclosureStyle.backgroundColor,
          borderRadius: disclosureStyle.borderRadius,
          overflow: disclosureStyle.overflow,
          summaryPadding: summaryStyle.padding,
          headingFontSize: headingStyle.fontSize
        }
      })
    JS
    expect(disclosure_styles.uniq.size).to eq(1)
    expect(disclosure_styles.first.fetch("backgroundColor")).to eq("rgb(255, 255, 255)")
    expect(disclosure_styles.first.fetch("overflow")).to eq("hidden")

    sources = find("#sources", visible: :all)
    expect(sources).to have_css(".report-source-link", minimum: 1, visible: :all)
    expect(sources).to have_css(".source-result", minimum: 1, visible: :all)
    expect(sources).to have_no_css(
      "[class*='text-emerald'], [class*='text-sky'], [class*='ring-emerald'], [class*='ring-sky']",
      visible: :all
    )

    graph = find("#ownership")
    expect(graph).to have_css("[data-property-graph-demo-banner]")
    expect(graph).to have_text(I18n.t("reports.property_graph.demo_title"))
    expect(graph).to have_css("[data-property-graph-target='node']", minimum: 8)
    expect(graph).to have_css(".property-graph__diagram", visible: true)
    expect(graph).to have_css("[data-edge-group='property_rights']")
    expect(graph).to have_css("[data-edge-group='property_context']")
    expect(
      graph.all(".property-graph__group", visible: :all).map { |group| group["data-edge-group"] }
    ).to start_with("property_rights")
    expect(graph).to have_css("[data-edge-group='property_rights'][open]")
    expect(graph).to have_css("[data-edge-group='property_context']:not([open])")
    expect(graph).to have_no_css(".property-graph__status.bg-sky-50", visible: :all)
    page.execute_script("arguments[0].scrollIntoView({ block: 'start' })", graph.native)
    expect(graph).to have_css("[data-property-graph-target='node'].is-selected", count: 1)
    diagram_style = page.evaluate_script(<<~JS)
      (() => {
        const style = getComputedStyle(document.querySelector(".property-graph__diagram"))
        return { backgroundColor: style.backgroundColor, backgroundImage: style.backgroundImage }
      })()
    JS
    expect(diagram_style.fetch("backgroundColor")).to eq("rgb(255, 255, 255)")
    expect(diagram_style.fetch("backgroundImage")).to include("radial-gradient")
    expect(graph).to have_css("svg [data-edge-label]", minimum: 1, visible: :all)

    overlaps = page.evaluate_script(<<~JS)
      (() => {
        const nodes = [...document.querySelectorAll("[data-property-graph-target='node']")]
        const labels = [...document.querySelectorAll("[data-edge-label]")]
        return labels.flatMap((label, labelIndex) => {
          const a = label.getBoundingClientRect()
          return nodes.filter((node) => {
            const b = node.getBoundingClientRect()
            return a.left < b.right && a.right > b.left && a.top < b.bottom && a.bottom > b.top
          }).map((node) => [labelIndex, label.textContent, node.dataset.nodeKey])
        })
      })()
    JS
    expect(overlaps).to be_empty

    label_overlaps = page.evaluate_script(<<~JS)
      (() => {
        const labels = [...document.querySelectorAll("[data-edge-label]")]
        return labels.flatMap((label, index) => {
          const a = label.getBoundingClientRect()
          return labels.slice(index + 1).filter((candidate) => {
            const b = candidate.getBoundingClientRect()
            return a.left < b.right && a.right > b.left && a.top < b.bottom && a.bottom > b.top
          }).map((candidate) => [label.textContent, candidate.textContent])
        })
      })()
    JS
    expect(label_overlaps).to be_empty

    company_name = "[ДЕМО] МЕСТО ИМОТИ ЕООД"
    graph.find("[data-property-graph-target='node']", text: company_name).click
    expect(graph).to have_css("[data-property-graph-target='panel']:not([hidden])", text: "000000000")
    expect(graph).to have_css("[data-property-graph-target='node'].is-selected", text: company_name)
    expect(graph).to have_css("svg line", minimum: 7, visible: :all)

    graph.all("details.property-graph__group:not([open])", visible: :all).each do |group|
      group.find("summary").click
    end
    page.current_window.resize_to(390, 844)
    expect(graph).to have_no_css("[data-property-graph-target='diagram']", visible: true)
    expect(graph).to have_text(I18n.t("reports.property_graph.structured_title"))
    expect(graph).to have_text(
      I18n.t(
        "reports.property_graph.registered_owner_as_of",
        owner: company_name,
        date: I18n.l(Date.new(2026, 9, 1), format: :short)
      )
    )
    expect(graph).to have_text("[ДЕМО] Предишен вписан собственик")
    expect(graph).to have_text("[ДЕМО] Текущ управител")
    expect(graph).to have_text("[ДЕМО] Предишен управител")
    expect(graph).to have_text("[ДЕМО] Едноличен собственик на капитала")
    expect(graph).to have_text("[ДЕМО] Действителен собственик")
  end

  def create_cadastral_hierarchy
    factory = RGeo::Cartesian.preferred_factory(srid: 4326)
    ring = factory.linear_ring([
      factory.point(23.34, 42.63), factory.point(23.35, 42.63),
      factory.point(23.35, 42.64), factory.point(23.34, 42.64), factory.point(23.34, 42.63)
    ])
    geometry = factory.multi_polygon([ factory.polygon(ring) ])
    source_url = "https://kais.cadastre.bg/bg/OpenData"
    relevant_at = Time.zone.parse("2026-09-02")
    [
      [ "68134.1607.1254", "parcel", 1_250.0 ],
      [ "68134.1607.1254.1", "building", 480.0 ],
      [ identifier, "individual_object", 86.4 ]
    ].each do |cadastral_identifier, identifier_level, area_sqm|
      CadastralProperty.create!(
        cadastral_identifier:,
        identifier_level:,
        area_sqm:,
        address: "[ДЕМО ТЕСТ] София, Малинова долина",
        geometry:,
        source_archive_key: "test/#{identifier_level}.zip",
        source_url:,
        source_relevant_at: relevant_at
      )
    end
  end
end
