require "rails_helper"

RSpec.describe "Due-diligence directory", type: :system do
  it "shows each expandable topic on its own row at desktop and mobile widths" do
    analysis = create(:property_analysis, status: "partial")

    visit report_path(analysis)

    directory = find('[data-testid="due-diligence"]')
    expect(directory).to have_text(I18n.t("reports.due_diligence.title"))
    expect(directory).to have_css("details", count: 30)

    encumbrances = directory.find('details[data-topic="encumbrances"]')
    expect(encumbrances[:open]).to eq("false")
    encumbrances.find("summary").click
    expect(encumbrances[:open]).to eq("true")
    expect(encumbrances).to have_text(I18n.t("reports.due_diligence.topics.encumbrances.obtain"))
    expect(encumbrances).to have_text(I18n.t("reports.due_diligence.topics.encumbrances.importance"))
    expect(encumbrances).to have_link(
      I18n.t("reports.due_diligence.sources.property_registry"),
      href: "https://portal.registryagency.bg/home-pr"
    )
    expect(topic_background("encumbrances")).to eq(topic_background("title_chain"))

    expect(grid_column_count).to eq(1)
    page.current_window.resize_to(390, 844)
    expect(grid_column_count).to eq(1)
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
end
