require "rails_helper"

RSpec.describe "Report reading hierarchy", type: :system do
  after { page.current_window.resize_to(1_400, 1_000) }

  it "puts the decision summary before detailed evidence and reflows it on mobile" do
    analysis = create(
      :property_analysis,
      status: "partial",
      coverage_status: "partial",
      metrics: { "direct_activity" => { "total" => 0, "by_registry" => {} } }
    )

    page.current_window.resize_to(1_400, 1_000)
    visit report_path(public_token: analysis)

    expect(page).to have_css("#overview .report-priority-card", count: 3)
    expect(page).to have_link(I18n.t("reports.navigation.overview"), href: "#overview")
    expect(page).to have_text(I18n.t("reports.overview_summary.limits_title"))
    expect(page).to have_no_css(".report-coverage", visible: :all)
    expect(priority_column_count).to eq(3)
    expect(overview_bottom_borders).to eq({ "grid" => "0px", "overview" => "1px" })
    expect(section_order).to eq(%w[identity records ownership context next-steps due-diligence])
    expect(section_chrome.map { |section| section.fetch("id") }).to eq(section_order)
    expect(section_chrome.map { |section| section.except("id") }.uniq).to eq([
      {
        "backgroundColor" => "rgb(255, 255, 255)",
        "borderTopColor" => "rgb(185, 95, 63)",
        "borderTopWidth" => "3px",
        "borderRightWidth" => "1px",
        "borderRadius" => "6px",
        "headerPadding" => "28px 30px 26px",
        "titleFontSize" => "30px",
        "titleLineHeight" => "36px"
      }
    ])
    expect(toc_position).to eq("sticky")
    expect(scroll_behavior).to eq("auto")

    page.execute_script("window.__reportNavigationMarker = 'preserved'")
    find(".report-toc a[href='#identity']").click
    expect(page.current_url).to end_with("#identity")
    expect(page.evaluate_script("window.__reportNavigationMarker")).to eq("preserved")

    page.current_window.resize_to(390, 844)

    expect(priority_column_count).to eq(1)
    expect(toc_position).to eq("static")
    expect(section_chrome.map { |section| section.except("id") }.uniq.size).to eq(1)
    expect(section_chrome.first.slice("headerPadding", "titleFontSize", "titleLineHeight")).to eq(
      "headerPadding" => "22px 20px 20px",
      "titleFontSize" => "24px",
      "titleLineHeight" => "28.8px"
    )
    expect(page_width).to be <= viewport_width
  end

  it "omits rerunning from a completed report and presents a new-property action instead" do
    analysis = create(
      :property_analysis,
      status: "ready",
      coverage_status: "complete",
      metrics: {
        "direct_activity" => { "total" => 0, "by_registry" => {} },
        "amenities" => {
          "availability" => { "schools" => true, "kindergartens" => true },
          "schools" => { "500" => 0 },
          "kindergartens" => { "500" => 0 }
        }
      }
    )
    gateway = Payments::FakeGateway.new
    order = gateway.create_order(property_analysis: analysis, email: "buyer@example.com")
    gateway.succeed(order)

    visit report_path(public_token: analysis)

    expect(page).to have_link(I18n.t("navigation.new_search"), href: root_path)
    expect(page).to have_no_button(I18n.t("reports.refresh.action"))
    expect(page).to have_css("[data-testid='due-diligence']")
    expect(page).to have_css("section[data-amenity-category]", count: 2)
    expect(page).to have_no_css("details[data-amenity-category]", visible: :all)
    expect(page).to have_no_css(".full-report-amenity-grid", visible: :all)
    expect(page).to have_no_text(I18n.t("reports.full.nearby"))
    expect(page.text.scan(I18n.t("reports.disclaimer", product_name: "Mesto")).size).to eq(1)
  end

  it "keeps the footer flush with the viewport on a short report" do
    analysis = create(:property_analysis, status: "queued")
    page.current_window.resize_to(1_400, 1_600)

    visit report_path(public_token: analysis)

    layout = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const footer = document.querySelector(".site-footer").getBoundingClientRect()
        return {
          footerBottom: footer.bottom,
          viewportBottom: window.innerHeight,
          documentHeight: document.documentElement.scrollHeight
        }
      })()
    JAVASCRIPT
    expect(layout.fetch("footerBottom")).to be_within(1).of(layout.fetch("viewportBottom"))
    expect(layout.fetch("documentHeight")).to eq(layout.fetch("viewportBottom"))
  end

  def priority_column_count
    page.evaluate_script(<<~JAVASCRIPT)
      getComputedStyle(document.querySelector('.report-priority-grid'))
        .gridTemplateColumns
        .split(' ')
        .length
    JAVASCRIPT
  end

  def overview_bottom_borders
    page.evaluate_script(<<~JAVASCRIPT)
      ({
        grid: getComputedStyle(document.querySelector('.report-priority-grid')).borderBottomWidth,
        overview: getComputedStyle(document.querySelector('.report-overview')).borderBottomWidth
      })
    JAVASCRIPT
  end

  def section_order
    page.evaluate_script(<<~JAVASCRIPT)
      Array.from(document.querySelectorAll('#identity, #records, #ownership, #context, #next-steps, #due-diligence'))
        .map((section) => section.id)
    JAVASCRIPT
  end

  def section_chrome
    page.evaluate_script(<<~JAVASCRIPT)
      Array.from(document.querySelectorAll('.report-section')).map((section) => {
        const sectionStyle = getComputedStyle(section)
        const headerStyle = getComputedStyle(section.querySelector('.report-section__header'))
        const titleStyle = getComputedStyle(section.querySelector('.report-section__header h2'))

        return {
          id: section.id,
          backgroundColor: sectionStyle.backgroundColor,
          borderTopColor: sectionStyle.borderTopColor,
          borderTopWidth: sectionStyle.borderTopWidth,
          borderRightWidth: sectionStyle.borderRightWidth,
          borderRadius: sectionStyle.borderRadius,
          headerPadding: headerStyle.padding,
          titleFontSize: titleStyle.fontSize,
          titleLineHeight: titleStyle.lineHeight
        }
      })
    JAVASCRIPT
  end

  def toc_position
    page.evaluate_script("getComputedStyle(document.querySelector('.report-toc')).position")
  end

  def scroll_behavior
    page.evaluate_script("getComputedStyle(document.documentElement).scrollBehavior")
  end

  def page_width
    page.evaluate_script("document.documentElement.scrollWidth")
  end

  def viewport_width
    page.evaluate_script("window.innerWidth")
  end
end
