module DataSources
  class HttpClient
    class DisallowedHost < StandardError; end

    TRANSIENT_ERRORS = [ Faraday::TimeoutError, Faraday::ConnectionFailed ].freeze

    def initialize(open_timeout: nil, read_timeout: nil, retries: nil)
      options = DataSources.config.fetch("http")
      @connection = Faraday.new do |faraday|
        faraday.request :retry,
          max: retries.nil? ? options.fetch("retries") : retries,
          interval: 0.2,
          backoff_factor: 2,
          exceptions: TRANSIENT_ERRORS
        faraday.options.open_timeout = open_timeout || options.fetch("open_timeout")
        faraday.options.timeout = read_timeout || options.fetch("read_timeout")
        faraday.response :raise_error
      end
    end

    def get(url, params = {}, headers = {})
      validate_url!(url)
      @connection.get(url, params, default_headers.merge(headers))
    end

    def post(url, params = {}, headers = {})
      validate_url!(url)
      @connection.post(url, params, default_headers.merge(headers))
    end

    private

    def validate_url!(url)
      uri = URI.parse(url)
      allowed = DataSources.config.fetch("allowed_hosts")
      raise DisallowedHost, "Remote host is not allowlisted" unless uri.is_a?(URI::HTTPS) && allowed.include?(uri.host)
    rescue URI::InvalidURIError
      raise DisallowedHost, "Remote URL is invalid"
    end

    def default_headers
      {
        "Accept" => "application/json, text/html;q=0.9",
        "User-Agent" => "Mesto/0.1 public-data client (+https://mesto.bg)"
      }
    end
  end
end
