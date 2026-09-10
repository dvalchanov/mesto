require "rails_helper"

RSpec.describe "Due-diligence directory", type: :system do
  it "shows each expandable topic on its own row at desktop and mobile widths" do
    analysis = create(:property_analysis, status: "partial")

    page.current_window.resize_to(1_400, 1_000)
    visit report_path(public_token: analysis)

    directory = find('[data-testid="due-diligence"]')
    expect(directory).to have_text(I18n.t("reports.due_diligence.title"))
    expect(directory).to have_css(".due-diligence-path article", count: 3)
    expect(directory).to have_text(I18n.t("reports.due_diligence.path.documents.title"))
    expect(directory).to have_css("details", count: 30)

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

    expect(path_column_count).to eq(3)
    expect(grid_column_count).to eq(1)
    page.current_window.resize_to(390, 844)
    expect(path_column_count).to eq(1)
    expect(grid_column_count).to eq(1)
  end

  after do
    page.current_window.resize_to(1_400, 1_000)
  end

  def path_column_count
    page.evaluate_script(<<~JAVASCRIPT)
      getComputedStyle(document.querySelector('.due-diligence-path'))
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
end
