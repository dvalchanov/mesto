require "rails_helper"

RSpec.describe "Property finder", type: :system do
  let(:factory) { RGeo::Cartesian.preferred_factory(srid: 4326) }
  let(:source) do
    {
      source_archive_key: "test/cadastre.zip",
      source_url: "https://kais.cadastre.bg/bg/OpenData"
    }
  end

  before do
    page.current_window.resize_to(1_400, 1_000)
    CadastralProperty.create!(
      **source,
      identifier_level: "building",
      cadastral_identifier: "68134.1609.4464.1",
      address: "гр. София, ул. Тестова №25",
      objects_count: 1,
      geometry: factory.parse_wkt("POLYGON((23.340 42.640,23.341 42.640,23.341 42.641,23.340 42.641,23.340 42.640))")
    )
    CadastralProperty.create!(
      **source,
      identifier_level: "individual_object",
      cadastral_identifier: "68134.1609.4464.1.16",
      address: "гр. София, ул. Тестова №25, ет. 2, ап. 16",
      floor: "2",
      object_number: "16",
      area_sqm: 75.2,
      purpose: "Жилище, апартамент",
      purpose_code: "500",
      geometry: factory.parse_wkt("POLYGON((23.340 42.640,23.341 42.640,23.341 42.641,23.340 42.641,23.340 42.640))")
    )
    CadastralProperty.create!(
      **source,
      identifier_level: "building",
      cadastral_identifier: "68134.1609.4465.1",
      address: "гр. София, ул. Друга №10",
      objects_count: 1,
      geometry: factory.parse_wkt("POLYGON((23.3412 42.640,23.3416 42.640,23.3416 42.6404,23.3412 42.6404,23.3412 42.640))")
    )
  end

  it "shows the candidate positions after the visitor chooses a floor" do
    visit property_finder_path(
      address: "Тестова 25",
      building_identifier: "68134.1609.4464.1",
      floor: "2"
    )

    expect(page).to have_css(".apartment-position[data-map-ready='true']")
    expect(page).to have_css(".apartment-position .maplibregl-canvas")
    expect(page).to have_css(".finder-candidate[data-cadastral-identifier='68134.1609.4464.1.16']")
  end

  it "centers the map on covered buildings and lets the visitor choose one" do
    visit root_path

    click_button I18n.t("property_finder.locator.open_map")

    expect(page).to have_css("dialog[open][data-building-count='2']", wait: 15)
    expect(page).to have_content(I18n.t("property_finder.locator.results", count: 2))

    dialog_gaps = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const bounds = document.querySelector(".property-locator-dialog").getBoundingClientRect()
        return {
          horizontal: [bounds.left, document.documentElement.clientWidth - bounds.right],
          vertical: [bounds.top, window.innerHeight - bounds.bottom]
        }
      })()
    JAVASCRIPT
    expect(dialog_gaps.fetch("horizontal").reduce(:-).abs).to be < 2
    expect(dialog_gaps.fetch("vertical").reduce(:-).abs).to be < 2

    map_input = find("dialog[open] input[data-property-locator-target='mapInput']")
    map_input.click
    map_input.send_keys("Тестова 25")
    expect(map_input.value).to eq("Тестова 25")
    map_input.send_keys(:enter)
    expect(page).to have_css("dialog[open][data-building-count='1']", wait: 15)

    map_canvas = find(".property-locator-dialog__map .maplibregl-canvas")
    scroll_origin = Selenium::WebDriver::WheelActions::ScrollOrigin.element(map_canvas.native)
    page.driver.browser.action.scroll_from(scroll_origin, 0, -240).perform
    sleep 1
    expect(page).to have_css("dialog[open][data-building-count='1']")

    map_canvas.click
    expect(page).to have_button(I18n.t("property_finder.locator.choose"))

    popup_close = find(".property-locator-dialog .maplibregl-popup-close-button")
    popup_close_size = page.evaluate_script(<<~JAVASCRIPT, popup_close)
      (() => {
        const bounds = arguments[0].getBoundingClientRect()
        return [bounds.width, bounds.height]
      })()
    JAVASCRIPT
    expect(popup_close_size).to all(be >= 32)
    popup_close.click
    expect(page).to have_no_css(".property-locator__popup")

    map_canvas.click
    expect(page).to have_button(I18n.t("property_finder.locator.choose"))
    click_button I18n.t("property_finder.locator.choose")

    expect(page).to have_current_path(property_finder_path, ignore_query: true)
    expect(page).to have_css(
      "input[name='building_identifier'][value='68134.1609.4464.1']",
      visible: :all
    )
  end
end
