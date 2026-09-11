require "rails_helper"

RSpec.describe "Due-diligence plan", type: :system do
  it "shows actionable property priorities and keeps the complete guide visible" do
    analysis = create(:property_analysis, status: "partial")
    CadastralProperty.create!(
      cadastral_identifier: analysis.submitted_identifier,
      identifier_level: analysis.identifier_level,
      area_sqm: 67.3,
      purpose: "Жилище, апартамент",
      address: "гр. София, вх. А, ет. 2, ап. 8",
      entrance: "А",
      floor: "2",
      object_number: "8",
      additional_parts: "2.38% (10.43 кв.м.) общи части",
      source_archive_key: "test/individual-objects.zip",
      source_url: "https://kais.cadastre.bg/bg/OpenData/Download?path=objects",
      source_relevant_at: Time.zone.parse("2026-09-02")
    )

    page.current_window.resize_to(1_400, 1_000)
    visit report_path(public_token: analysis)

    directory = find('[data-testid="due-diligence"]')
    plan = find("#next-steps")
    expect(plan.text).to include(
      I18n.t("reports.buyer_checklist.title"),
      I18n.t("reports.due_diligence.guide_title")
    )
    expect(plan).to have_css(".buyer-priority-label")
    expect(plan).to have_css(".buyer-priority-list > li", count: 6)
    first_priority = plan.find(".buyer-priority-list > li:first-child")
    expect(first_priority.find(".buyer-priority-list__title h3")).to have_text(
      I18n.t("reports.due_diligence.topics.area_comparison.title")
    )
    expect(first_priority).to have_css(".buyer-priority-list__known")
    [
      I18n.t("reports.buyer_checklist.known_values_label"),
      I18n.t("reports.buyer_checklist.fact_labels.subject_area"),
      "67.3 m²",
      "Жилище, апартамент",
      "вх. А · ет. 2 · обект № 8",
      "2.38% (10.43 кв.м.) общи части"
    ].each { |text| expect(first_priority).to have_text(text) }
    expect(first_priority).to have_link(
      I18n.t("reports.due_diligence.sources.cadastre"),
      href: Analysis::DueDiligenceBuilder::SOURCE_URLS.fetch("cadastre")
    )
    expect(first_priority).to have_no_link(href: "https://kais.cadastre.bg/bg/OpenData/Download?path=objects")
    expect(plan).to have_no_css(".buyer-priority-list__status")
    expect(title_number_offsets.max).to be <= 1
    expect(directory).to have_css(".due-diligence-category", count: 6)
    expect(directory).to have_css('.due-diligence-guide__nav a[href^="#due-diligence-"]', count: 6)
    expect(directory).to have_css('details[data-topic]', count: 30, visible: true)
    expect(directory).to have_no_css("details details")
    expect(directory).to have_no_css(".due-diligence-guide__toggle")
    expect(page).to have_no_css('.report-toc a[href="#due-diligence"]')

    ownership = plan.find('[data-priority="ownership"]')
    expect(ownership).to have_text(I18n.t("reports.due_diligence.topics.title_chain.title"))
    expect(ownership).to have_text(analysis.submitted_identifier)
    expect(ownership).to have_button(I18n.t("reports.buyer_checklist.copy_identifier"))
    expect(ownership).to have_css(".buyer-priority-list__recipe li", count: 3)
    expect(ownership).to have_text(I18n.t("reports.buyer_checklist.priority_guides.title_chain.watch"))
    expect(ownership).to have_link(
      I18n.t("reports.due_diligence.sources.property_registry_search_help"),
      href: Analysis::DueDiligenceBuilder::SOURCE_URLS.fetch("property_registry_search_help")
    )

    title_chain = directory.find('details[data-topic="title_chain"]')
    expect(title_chain[:open]).to eq("false")
    ownership.click_link(I18n.t("reports.buyer_checklist.full_topic"))
    expect(title_chain[:open]).to eq("true")
    expect(page.current_url).to end_with("#due-diligence-topic-title_chain")

    encumbrances = directory.find('details[data-topic="encumbrances"]')
    expect(encumbrances[:open]).to eq("false")
    expect(encumbrances).to have_text(I18n.t("reports.due_diligence.results.external_official_check"))
    expect(encumbrances).to have_text(I18n.t("reports.due_diligence.open_topic"))
    encumbrances.find("summary").click
    expect(encumbrances[:open]).to eq("true")
    expect(encumbrances).to have_text(I18n.t("reports.due_diligence.topics.encumbrances.obtain"))
    expect(encumbrances).to have_text(I18n.t("reports.due_diligence.topics.encumbrances.importance"))
    expect(encumbrances).to have_link(
      I18n.t("reports.due_diligence.sources.property_registry_certificate_help"),
      href: Analysis::DueDiligenceBuilder::SOURCE_URLS.fetch("property_registry_certificate_help")
    )
    expect(topic_background("encumbrances")).to eq(topic_background("title_chain"))
    expect(topic_summary_padding("technical_inspection")).to eq(topic_summary_padding("approved_layout"))
    expect(status_background("technical_inspection")).not_to eq(status_background("cadastre_identity"))
    expect(font_size(".buyer-priority-list__recipe p")).to be >= 14
    expect(font_size(".due-diligence-guide__heading p:not(.report-section-label)")).to be >= 14
    expect(font_size(".due-diligence-topic__summary h5")).to be >= 15

    expect(priority_column_count).to eq(1)
    expect(priority_positions.each_cons(2).all? { |first, second| second.fetch("top") > first.fetch("top") }).to be(true)
    expect(priority_positions.map { |position| position.fetch("left") }.uniq.one?).to be(true)
    expect(grid_column_count).to eq(1)
    page.current_window.resize_to(390, 844)
    expect(priority_column_count).to eq(1)
    expect(title_number_offsets.max).to be <= 1
    expect(grid_column_count).to eq(1)
    expect(directory.find('details[data-topic="building_permit"]')).to have_text(
      I18n.t("reports.due_diligence.open_topic")
    )
    expect(page_width).to be <= viewport_width
  end

  after do
    page.current_window.resize_to(1_400, 1_000)
  end

  def priority_column_count
    page.evaluate_script(<<~JAVASCRIPT)
      getComputedStyle(document.querySelector('.buyer-priority-list'))
        .gridTemplateColumns
        .split(' ')
        .length
    JAVASCRIPT
  end

  def title_number_offsets
    page.evaluate_script(<<~JAVASCRIPT)
      Array.from(document.querySelectorAll('.buyer-priority-list > li')).map((item) => {
        const title = item.querySelector('h3').getBoundingClientRect()
        const number = item.querySelector('.buyer-priority-list__number').getBoundingClientRect()
        return Math.abs((title.top + title.height / 2) - (number.top + number.height / 2))
      })
    JAVASCRIPT
  end

  def grid_column_count
    page.evaluate_script(<<~JAVASCRIPT)
      getComputedStyle(document.querySelector('.due-diligence-grid'))
        .gridTemplateColumns
        .split(' ')
        .length
    JAVASCRIPT
  end

  def priority_positions
    page.evaluate_script(<<~JAVASCRIPT)
      Array.from(document.querySelectorAll('.buyer-priority-list > li')).map((item) => {
        const bounds = item.getBoundingClientRect()
        return { top: Math.round(bounds.top), left: Math.round(bounds.left) }
      })
    JAVASCRIPT
  end

  def topic_background(topic)
    page.evaluate_script(<<~JAVASCRIPT)
      getComputedStyle(document.querySelector('[data-topic="#{topic}"]'))
        .backgroundColor
    JAVASCRIPT
  end

  def topic_summary_padding(topic)
    page.evaluate_script(<<~JAVASCRIPT)
      getComputedStyle(document.querySelector('[data-topic="#{topic}"] > summary'))
        .paddingLeft
    JAVASCRIPT
  end

  def status_background(topic)
    page.evaluate_script(<<~JAVASCRIPT)
      getComputedStyle(document.querySelector('[data-topic="#{topic}"] .due-diligence-status'))
        .backgroundColor
    JAVASCRIPT
  end

  def font_size(selector)
    page.evaluate_script(<<~JAVASCRIPT)
      parseFloat(getComputedStyle(document.querySelector('#{selector}')).fontSize)
    JAVASCRIPT
  end

  def page_width
    page.evaluate_script("document.documentElement.scrollWidth")
  end

  def viewport_width
    page.evaluate_script("window.innerWidth")
  end
end
