require "rails_helper"

RSpec.describe "Property finder", type: :request do
  let(:factory) { RGeo::Cartesian.preferred_factory(srid: 4326) }
  let(:building_geometry) { factory.parse_wkt("POLYGON((23.340 42.640,23.342 42.640,23.342 42.642,23.340 42.642,23.340 42.640))") }
  let(:unit_geometry) { factory.parse_wkt("POLYGON((23.340 42.640,23.341 42.640,23.341 42.641,23.340 42.641,23.340 42.640))") }
  let(:source) do
    {
      identifier_level: "individual_object",
      source_archive_key: "test/individual-objects.zip",
      source_url: "https://kais.cadastre.bg/bg/OpenData",
      purpose: "Жилище, апартамент",
      purpose_code: "500"
    }
  end

  before do
    CadastralProperty.create!(
      identifier_level: "building",
      cadastral_identifier: "68134.1609.4464.1",
      source_archive_key: "test/buildings.zip",
      source_url: "https://kais.cadastre.bg/bg/OpenData",
      address: "гр. София, ул. Тестова №25",
      street_number: "25",
      objects_count: 2,
      geometry: building_geometry
    )
    CadastralProperty.create!(
      **source,
      cadastral_identifier: "68134.1609.4464.1.16",
      address: "гр. София, ул. Тестова №25, вх. А, ет. 2, ап. А16",
      street_number: "25",
      entrance: "А", floor: "2", object_number: "А16", area_sqm: 75.2,
      geometry: unit_geometry
    )
    CadastralProperty.create!(
      **source,
      cadastral_identifier: "68134.1609.4464.1.17",
      address: "гр. София, вх. А, ет. 3, ап. А17",
      entrance: "А", floor: "3", object_number: "А17", area_sqm: 82.4,
      geometry: unit_geometry
    )
  end

  it "makes address the default entry point while retaining direct identifier search" do
    get root_path

    page = Nokogiri::HTML5(response.body)
    expect(page.at_css("form[action='#{property_finder_path}'] input[name='address']")).to be_present
    expect(response.body).to include(I18n.t("home.search.address_hint_title"))
    expect(page.at_css("#search-tab-address")["href"]).to eq(root_path)
    expect(page.at_css("#search-tab-identifier")["href"]).to eq(root_path(search: "identifier"))

    get root_path(search: "identifier")

    page = Nokogiri::HTML5(response.body)
    expect(page.at_css("form[action='#{property_analyses_path}'] input[name='cadastral_identifier']")).to be_present
  end

  it "shows all units in an address-matched building without creating a report" do
    expect {
      get property_finder_path, params: { address: "ул. Тестова 25" }
    }.not_to change(PropertyAnalysis, :count)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      "68134.1609.4464.1.16",
      "68134.1609.4464.1.17",
      I18n.t("property_finder.candidates.select")
    )
    expect(Nokogiri::HTML5(response.body).css(".finder-candidate__purpose").count).to eq(2)
    expect(response.body).to include('name="robots" content="noindex,follow"')
  end

  it "filters the options by known apartment details" do
    get property_finder_path, params: { address: "Тестова 25", floor: "3", area: "82" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("68134.1609.4464.1.17")
    expect(response.body).not_to include("68134.1609.4464.1.16")
  end

  it "offers local address suggestions with building ambiguity" do
    get property_address_suggestions_path, params: { q: "Тестова 25" }, as: :json

    expect(response).to have_http_status(:ok)
    suggestion = response.parsed_body.fetch("suggestions").first
    expect(suggestion).to include(
      "address" => "гр. София, ул. Тестова №25",
      "building_count" => 1,
      "building_identifier" => "68134.1609.4464.1"
    )
  end

  it "returns cadastral building geometry for a map viewport" do
    get property_finder_buildings_path, params: { bbox: "23.33,42.63,23.35,42.65" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("meta", "count")).to eq(1)
    expect(response.parsed_body.fetch("features").first.dig("properties", "identifier")).to eq("68134.1609.4464.1")
  end

  it "centers the initial map on a building inside the available coverage" do
    get property_finder_buildings_path, params: { initial: true }, as: :json

    expect(response).to have_http_status(:ok)
    longitude, latitude = response.parsed_body.dig("meta", "center")
    expect(longitude).to be_between(23.340, 23.342)
    expect(latitude).to be_between(42.640, 42.642)
  end

  it "uses an exact map-selected building and renders the chosen floor position map" do
    get property_finder_path, params: {
      address: "гр. София, ул. Тестова №25",
      building_identifier: "68134.1609.4464.1",
      floor: "2"
    }

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML5(response.body)
    expect(page.at_css("[data-controller='apartment-position']")).to be_present
    expect(response.body).to include("68134.1609.4464.1.16")
    expect(response.body).not_to include("68134.1609.4464.1.17")
  end

  it "uses the selected exact object to start the existing report flow" do
    expect {
      post property_analyses_path, params: {
        cadastral_identifier: "68134.1609.4464.1.17",
        discovery_method: "address"
      }
    }.to change(PropertyAnalysis, :count).by(1)

    expect(response).to redirect_to(report_path(public_token: PropertyAnalysis.last))
    expect(ProductEvent.where(name: "search_submitted").last.metadata).to include("discovery_method" => "address")
  end

  it "retains map selection as the report discovery method" do
    post property_analyses_path, params: {
      cadastral_identifier: "68134.1609.4464.1.17",
      discovery_method: "map"
    }

    expect(response).to redirect_to(report_path(public_token: PropertyAnalysis.last))
    expect(ProductEvent.where(name: "search_submitted").last.metadata).to include("discovery_method" => "map")
  end

  it "renders the finder in English under the locale prefix" do
    get property_finder_path(locale: :en), params: { address: "Тестова 25" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Which apartment is it?", "This is the property")
  end
end
