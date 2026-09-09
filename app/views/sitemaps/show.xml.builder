xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset "xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9", "xmlns:xhtml" => "http://www.w3.org/1999/xhtml" do
  origin = "https://#{Rails.application.config.x.app_host}"
  @paths.uniq.each do |path|
    localized_urls = {
      "bg" => "#{origin}#{path}",
      "en" => "#{origin}/en#{path == '/' ? '' : path}"
    }

    localized_urls.each_value do |url|
      xml.url do
        xml.loc url
        localized_urls.each do |locale, alternate_url|
          xml.tag! "xhtml:link", rel: "alternate", hreflang: locale, href: alternate_url
        end
        xml.tag! "xhtml:link", rel: "alternate", hreflang: "x-default", href: localized_urls.fetch("bg")
      end
    end
  end
end
