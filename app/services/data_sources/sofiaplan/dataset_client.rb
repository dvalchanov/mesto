module DataSources
  module Sofiaplan
    class DatasetClient
      def initialize(http_client: HttpClient.new)
        @http_client = http_client
        @base_url = DataSources.config.dig("sofiaplan", "base_url")
      end

      def fetch(dataset_id)
        url = "#{@base_url}/datasets/#{dataset_id}"
        body = if DataSources.fixture?
          FixtureLoader.read("sofiaplan_geojson.json")
        else
          @http_client.get(url, {}, "Accept" => "application/geo+json, application/json").body
        end
        payload = JSON.parse(body)
        raise JSON::ParserError, "Expected a GeoJSON FeatureCollection" unless payload["type"] == "FeatureCollection"

        Result.success(data: payload, source_url: url, raw_response: body)
      rescue JSON::ParserError => error
        Result.failure(source_url: url, error: error)
      rescue StandardError => error
        Result.unavailable(source_url: url, error: error)
      end
    end
  end
end
