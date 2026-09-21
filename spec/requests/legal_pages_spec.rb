require "rails_helper"

RSpec.describe "Legal and data-transparency pages", type: :request do
  let(:paths) do
    [
      legal_notice_path,
      terms_of_use_path,
      privacy_policy_path,
      cookie_policy_path,
      data_sources_policy_path
    ]
  end

  it "publishes every page in Bulgarian and English with company identity" do
    paths.each do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("КАДИВЕЛ ЕООД", "208282493")

      get "/en#{path}"
      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML5(response.body).at_css("html")["lang"]).to eq("en")
      expect(response.body).to include("KADIVEL EOOD", "208282493")
    end
  end

  it "lists used sources without exposing internal launch statuses or unused candidates" do
    get data_sources_policy_path

    expect(response.body).to include(
      "АГКК / КАИС",
      "Софияплан API",
      "OpenStreetMap",
      "European Commission VIES",
      "OpenFreeMap"
    )
    expect(response.body).not_to include(
      "Правен преглед - блокиран",
      "Нужен договор - не се използва",
      "review_required",
      "contract_required",
      "Търговски регистър",
      "Имотен регистър"
    )
  end

  it "links the legal documents and operator identity from the site footer" do
    get root_path
    page = Nokogiri::HTML5(response.body)

    expect(page.at_css(".site-footer").text).to include("КАДИВЕЛ ЕООД", "208282493")
    paths.each do |path|
      expect(page.at_css(".site-footer a[href='#{path}']")).to be_present
    end
  end

  it "uses the general address for support and the legal address for privacy" do
    get legal_notice_path
    expect(response.body).to include("mailto:hi@mesto.bg", "mailto:legal@mesto.bg")

    get privacy_policy_path
    expect(response.body).to include("mailto:legal@mesto.bg")
    expect(response.body).not_to include("privacy@mesto.bg", "hello@mesto.bg")
  end
end
