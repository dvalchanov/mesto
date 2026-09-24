require "rails_helper"

RSpec.describe "Home page", type: :system do
  let(:factory) { RGeo::Cartesian.preferred_factory(srid: 4326) }

  it "switches property search methods without moving the page" do
    visit root_path
    page.execute_script("window.scrollTo(0, 120)")
    starting_position = page.evaluate_script("window.scrollY")

    click_link I18n.t("home.search.by_identifier")

    expect(page).to have_field(I18n.t("home.search.label"))
    expect(page).to have_css("#search-tab-identifier[aria-selected='true']")
    expect(page.evaluate_script("window.scrollY")).to be_within(1).of(starting_position)

    click_link I18n.t("home.search.by_address")

    expect(page).to have_field(I18n.t("home.search.address_label"))
    expect(page).to have_css("#search-tab-address[aria-selected='true']")
    expect(page.evaluate_script("window.scrollY")).to be_within(1).of(starting_position)
  end

  it "uses consistent typography in both property search fields" do
    visit root_path

    font_families = page.evaluate_script(<<~JAVASCRIPT)
      [document.querySelector("input[name='address']"), document.querySelector("input[name='cadastral_identifier']")]
        .flatMap((input) => [
          getComputedStyle(input).fontFamily,
          getComputedStyle(input, "::placeholder").fontFamily
        ])
    JAVASCRIPT

    expect(font_families.uniq.size).to eq(1)
  end

  it "keeps the final call-to-action text readable" do
    visit root_path

    button = find(".home-cta .button--subtle")
    colors = page.evaluate_script(<<~JS, button)
      (() => {
        const style = getComputedStyle(arguments[0])
        return { background: style.backgroundColor, text: style.color }
      })()
    JS

    expect(colors).to eq("background" => "rgb(251, 250, 247)", "text" => "rgb(23, 63, 52)")

    button.hover
    expect(page.evaluate_script("getComputedStyle(arguments[0]).color", button)).to eq("rgb(23, 63, 52)")
  end

  it "suggests a local building address and keeps its exact identifier" do
    CadastralProperty.create!(
      identifier_level: "building",
      cadastral_identifier: "68134.1609.4464.1",
      source_archive_key: "test/buildings.zip",
      source_url: "https://kais.cadastre.bg/bg/OpenData",
      address: "гр. София, ул. Тестова №25",
      street_number: "25",
      geometry: factory.parse_wkt("POLYGON((23.340 42.640,23.341 42.640,23.341 42.641,23.340 42.641,23.340 42.640))")
    )

    visit root_path
    fill_in I18n.t("home.search.address_label"), with: "Тестова 25"

    expect(page).to have_css(".property-locator__suggestion", text: "Тестова №25")
    find(".property-locator__suggestion", text: "Тестова №25").click

    expect(find("input[name='building_identifier']", visible: :all).value).to eq("68134.1609.4464.1")
    expect(page).to have_css(".property-locator__selection", text: I18n.t("property_finder.locator.selected"))
  end

  it "plays a localized explainer video that visitors can pause" do
    visit root_path(locale: "en")

    expect(page).to have_css(".home-film source[src*='mesto-explainer-en'][type='video/webm']", visible: :all)
    expect(page).to have_css("#home-film-summary", text: I18n.t("home.film.summary", locale: :en), visible: :all)

    page.execute_script("document.querySelector('.home-film video').scrollIntoView({ block: 'center' })")
    expect(page).to have_css(".home-film__toggle[data-state='playing']")

    find(".home-film__toggle").click

    expect(page).to have_css(".home-film__toggle[data-state='paused'][aria-label='#{I18n.t('home.film.play', locale: :en)}']")
  end

  it "opens building selection on a map without navigating away" do
    visit root_path

    click_button I18n.t("property_finder.locator.open_map")

    expect(page).to have_css("dialog.property-locator-dialog[open]")
    expect(page).to have_css(".property-locator-dialog__map")
    expect(page).to have_current_path(root_path)
  end
end
