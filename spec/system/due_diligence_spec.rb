require "rails_helper"

RSpec.describe "Due-diligence plan", type: :system do
  it "shows actionable property priorities and keeps the complete guide visible" do
    analysis = create(:property_analysis, status: "partial")

    page.current_window.resize_to(1_400, 1_000)
    visit report_path(public_token: analysis)

    directory = find('[data-testid="due-diligence"]')
    plan = find("#next-steps")
    expect(plan.text).to include(
      I18n.t("reports.buyer_checklist.title"),
      I18n.t("reports.due_diligence.guide_title")
    )
    expect(plan).to have_css(".buyer-priority-label")
    expect(plan).to have_css(".buyer-priority-list li", count: 6)
    expect(directory).to have_css(".due-diligence-category", count: 6)
    expect(directory).to have_css('details[data-topic]', count: 30, visible: true)
    expect(directory).to have_no_css("details details")
    expect(directory).to have_no_css(".due-diligence-guide__toggle")
    expect(page).to have_no_css('.report-toc a[href="#due-diligence"]')

    ownership = plan.find('[data-priority="ownership"]')
    expect(ownership).to have_text(I18n.t("reports.due_diligence.topics.title_chain.title"))
    expect(ownership).to have_text(I18n.t("reports.due_diligence.topics.title_chain.obtain"))
    expect(ownership).to have_link(
      I18n.t("reports.due_diligence.sources.property_registry"),
      href: "https://portal.registryagency.bg/home-pr"
    )

    encumbrances = directory.find('details[data-topic="encumbrances"]')
    expect(encumbrances[:open]).to eq("false")
    expect(encumbrances).to have_text(I18n.t("reports.due_diligence.results.external_official_check"))
    encumbrances.find("summary").click
    expect(encumbrances[:open]).to eq("true")
    expect(encumbrances).to have_text(I18n.t("reports.due_diligence.topics.encumbrances.obtain"))
    expect(encumbrances).to have_text(I18n.t("reports.due_diligence.topics.encumbrances.importance"))
    expect(encumbrances).to have_link(
      I18n.t("reports.due_diligence.sources.property_registry"),
      href: "https://portal.registryagency.bg/home-pr"
    )
    expect(topic_background("encumbrances")).to eq(topic_background("title_chain"))
    expect(font_size(".buyer-priority-list__instruction p")).to be >= 14
    expect(font_size(".due-diligence-guide__heading p:not(.report-section-label)")).to be >= 14
    expect(font_size(".due-diligence-topic__summary h5")).to be >= 15

    expect(priority_column_count).to eq(2)
    expect(grid_column_count).to eq(1)
    page.current_window.resize_to(390, 844)
    expect(priority_column_count).to eq(1)
    expect(grid_column_count).to eq(1)
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

  def grid_column_count
    page.evaluate_script(<<~JAVASCRIPT)
      getComputedStyle(document.querySelector('.due-diligence-grid'))
        .gridTemplateColumns
        .split(' ')
        .length
    JAVASCRIPT
  end

  def topic_background(topic)
    page.evaluate_script(<<~JAVASCRIPT)
      getComputedStyle(document.querySelector('[data-topic="#{topic}"]'))
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
