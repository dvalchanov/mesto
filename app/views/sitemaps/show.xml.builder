xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  @paths.uniq.each do |path|
    xml.url { xml.loc "https://#{Rails.application.config.x.app_host}#{path}" }
  end
end
