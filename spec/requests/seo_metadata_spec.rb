require "rails_helper"

RSpec.describe "SEO metadata", type: :request do
  def public_paths
    catalog = Education::Catalog.instance
    paths = [
      root_path(locale: nil),
      guide_path(locale: nil),
      buying_guide_path(locale: nil),
      new_build_guide_path(locale: nil),
      education_documents_path(locale: nil),
      terms_path(locale: nil),
      calculators_path(locale: nil),
      purchase_calculator_path(locale: nil),
      mortgage_calculator_path(locale: nil)
    ]
    paths += catalog.published("stage").map { |entry| new_build_stage_path(stage: entry["slug"], locale: nil) }
    paths += catalog.published("document").map { |entry| education_document_path(slug: entry["slug"], locale: nil) }
    paths += catalog.published("term").map { |entry| term_path(slug: entry["slug"], locale: nil) }
    paths.uniq
  end

  def localized_path(path, locale)
    locale == :en ? "/en#{path == '/' ? '' : path}" : path
  end

  it "gives every public Bulgarian and English page unique search metadata" do
    titles = Hash.new { |hash, locale| hash[locale] = {} }
    descriptions = Hash.new { |hash, locale| hash[locale] = {} }

    %i[bg en].each do |locale|
      public_paths.each do |base_path|
        path = localized_path(base_path, locale)
        get path

        expect(response).to have_http_status(:ok), "Expected #{path} to render"
        page = Nokogiri::HTML5(response.body)
        title = page.at_css("title")&.text&.strip
        description = page.at_css('meta[name="description"]')&.[]("content")&.strip
        canonical = "#{request.base_url}#{path}"

        expect(page.at_css("html")["lang"]).to eq(locale.to_s), "Wrong language on #{path}"
        expect(title).to be_present, "Missing title on #{path}"
        expect(description).to be_present, "Missing description on #{path}"
        expect(description.length).to be_between(60, 220), "Description length on #{path}: #{description.length}"
        expect(page.at_css('meta[property="og:title"]')["content"]).to eq(title)
        expect(page.at_css('meta[property="og:description"]')["content"]).to eq(description)
        expect(page.at_css('link[rel="canonical"]')["href"]).to eq(canonical)
        expect(page.at_css('link[rel="alternate"][hreflang="bg"]')["href"]).to eq("#{request.base_url}#{localized_path(base_path, :bg)}")
        expect(page.at_css('link[rel="alternate"][hreflang="en"]')["href"]).to eq("#{request.base_url}#{localized_path(base_path, :en)}")
        expect(page.at_css('link[rel="alternate"][hreflang="x-default"]')["href"]).to eq("#{request.base_url}#{localized_path(base_path, :bg)}")
        expect(page.at_css('meta[name="robots"]')).to be_nil, "Public page is noindex: #{path}"

        expect(titles[locale]).not_to have_key(title), "Duplicate #{locale} title on #{path} and #{titles[locale][title]}"
        expect(descriptions[locale]).not_to have_key(description), "Duplicate #{locale} description on #{path} and #{descriptions[locale][description]}"
        titles[locale][title] = path
        descriptions[locale][description] = path
      end
    end
  end

  it "keeps each language on stable URLs and preserves it in internal links" do
    get education_document_path(slug: "predvaritelen-dogovor", locale: :en)

    page = Nokogiri::HTML5(response.body)
    expect(page.at_css("html")["lang"]).to eq("en")
    expect(page.at_css('.locale-switch a[aria-current="page"]')["href"]).to eq(education_document_path(slug: "predvaritelen-dogovor", locale: :en))
    expect(page.at_css('.site-nav a')["href"]).to start_with("/en/")

    get education_document_path(slug: "predvaritelen-dogovor", locale: nil)
    expect(Nokogiri::HTML5(response.body).at_css("html")["lang"]).to eq("bg")

    get education_documents_path(locale: nil), params: { locale: "en", q: "Act 15" }
    expect(response).to redirect_to("/en/dokumenti?q=Act+15")
    expect(response).to have_http_status(:moved_permanently)
  end

  it "keeps search results and private workflow pages out of the index" do
    get education_documents_path(q: "акт 15")
    expect(response.body).to include('name="robots" content="noindex,follow"')

    get my_mesto_path
    expect(response.body).to include('name="robots" content="noindex,nofollow"')

    get budget_scenarios_path
    expect(response.body).to include('name="robots" content="noindex,nofollow"')

    analysis = create(:property_analysis, status: "ready", coverage_status: "complete", summary: { "paid_content_available" => true })
    get report_path(public_token: analysis)
    expect(response.body).to include('name="robots" content="noindex,nofollow"')

    get report_checkout_path(public_token: analysis)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="robots" content="noindex,nofollow"')

    order = Payments::FakeGateway.new.create_order(property_analysis: analysis, email: "buyer@example.com")
    get checkout_path(public_token: order)
    expect(response.body).to include('name="robots" content="noindex,nofollow"')
  end

  it "identifies Mesto as the website name on the homepage" do
    get root_path

    page = Nokogiri::HTML5(response.body)
    website_data = JSON.parse(page.at_css('script[type="application/ld+json"]').text)
    expect(website_data).to include(
      "@type" => "WebSite",
      "name" => "Mesto",
      "alternateName" => "Mesto.bg",
      "url" => "#{request.base_url}/",
      "inLanguage" => %w[bg en]
    )
  end

  it "lists every public page in both languages with reciprocal alternates" do
    get "/sitemap.xml"

    expect(response).to have_http_status(:ok)
    document = Nokogiri::XML(response.body)
    document.remove_namespaces!
    locations = document.xpath("//url/loc").map(&:text)

    expect(locations.length).to eq(public_paths.length * 2)
    public_paths.each do |path|
      expect(locations).to include("https://mesto.bg#{localized_path(path, :bg)}")
      expect(locations).to include("https://mesto.bg#{localized_path(path, :en)}")
    end
    expect(document.xpath("//url/link").length).to eq(locations.length * 3)
    expect(locations.join(" ")).not_to include("/reports/", "/checkout/", "/moeto-mesto", "/kalkulator/scenarii", "?")
  end
end
