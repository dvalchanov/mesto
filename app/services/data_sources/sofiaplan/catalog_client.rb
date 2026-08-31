module DataSources
  module Sofiaplan
    class CatalogClient
      def initialize(http_client: HttpClient.new)
        @http_client = http_client
        @base_url = DataSources.config.dig("sofiaplan", "base_url")
      end

      def version
        request_json("version", fixture: "sofiaplan_version.json")
      end

      def datasets
        request_json("datasets", fixture: "sofiaplan_catalog.json")
      end

      private

      def request_json(path, fixture:)
        url = "#{@base_url}/#{path}"
        body = DataSources.fixture? ? FixtureLoader.read(fixture) : @http_client.get(url).body
        Result.success(data: JSON.parse(body), source_url: url, raw_response: body)
      rescue JSON::ParserError => error
        Result.failure(source_url: url, error: error)
      rescue StandardError => error
        Result.unavailable(source_url: url, error: error)
      end
    end
  end
end
