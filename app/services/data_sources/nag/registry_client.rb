module DataSources
  module Nag
    class RegistryClient
      def initialize(registry_kind:, config:, http_client: HttpClient.new)
        @registry_kind = registry_kind.to_s
        @config = config.deep_stringify_keys
        @http_client = http_client
      end

      def search(identifiers:)
        return fixture_search if DataSources.fixture?

        index_response = @http_client.get(@config.fetch("url"))
        action = search_action(index_response.body)
        return Result.unavailable(source_url: @config.fetch("url"), error: StandardError.new("Public search form was not found")) unless action

        records = identifiers.compact.uniq.each_with_index.flat_map do |identifier, index|
          sleep(request_delay) if index.positive?
          response = @http_client.get(action, @config.fetch("identifier_field") => identifier)
          RegistryParser.new(registry_kind: @registry_kind, base_url: @config.fetch("url")).parse(response.body).each do |record|
            record["matched_identifier"] = identifier
          end
        end
        records = records.uniq { |record| record.fetch("external_key") }
        enrich_details(records)
        Result.success(data: records, source_url: @config.fetch("url"), fetched_at: Time.current)
      rescue Nokogiri::SyntaxError, JSON::ParserError => error
        Result.failure(source_url: @config.fetch("url"), error: error)
      rescue StandardError => error
        Result.unavailable(source_url: @config.fetch("url"), error: error)
      end

      private

      def fixture_search
        name = "nag_#{@registry_kind}_search.html"
        html = FixtureLoader.read(name)
        records = RegistryParser.new(registry_kind: @registry_kind, base_url: @config.fetch("url")).parse(html)
        enrich_details(records)
        Result.success(data: records, source_url: @config.fetch("url"), fetched_at: Time.current, raw_response: html)
      rescue StandardError => error
        Result.failure(source_url: @config.fetch("url"), error: error)
      end

      def search_action(html)
        document = Nokogiri::HTML5(html)
        form = document.at_css("form.search[action*='/Search']") || document.at_css("form[action*='/Search']")
        URI.join(@config.fetch("url"), form["action"]).to_s if form
      rescue URI::InvalidURIError
        nil
      end

      def enrich_details(records)
        records.first(detail_limit).each_with_index do |record, index|
          next if record["source_url"] == @config.fetch("url")

          sleep(request_delay) if !DataSources.fixture? && index.positive?
          html = DataSources.fixture? ? FixtureLoader.read("nag_detail.html") : @http_client.get(record.fetch("source_url")).body
          details = DetailParser.new.parse(html)
          record.merge!(details.except("cadastral_identifiers"))
          record["cadastral_identifiers"] = (record["cadastral_identifiers"] + Array(details["cadastral_identifiers"])).uniq
        rescue StandardError => error
          record["detail_error"] = error.class.name
        end
      end

      def request_delay
        DataSources.config.dig("nag", "request_delay_seconds").to_f
      end

      def detail_limit
        DataSources.config.dig("nag", "detail_limit").to_i
      end
    end
  end
end
