module DataSources
  module CadastreOpenData
    class ArchiveClient
      DOWNLOAD_URL = "https://kais.cadastre.bg/bg/OpenData/Download".freeze

      def initialize(config: DataSources.config.dig("cadastre", "open_data"))
        @config = config
      end

      def download(archive_key)
        validate_archive_key!(archive_key)
        url = "#{@config.fetch('download_url', DOWNLOAD_URL)}?#{URI.encode_www_form(path: archive_key)}"
        response = connection.get(url)
        tempfile = Tempfile.new([ "cadastre-open-data", ".zip" ])
        tempfile.binmode
        tempfile.write(response.body)
        tempfile.rewind
        yield tempfile.path, url
      ensure
        tempfile&.close!
      end

      private

      def connection
        @connection ||= Faraday.new do |faraday|
          faraday.request :retry,
            max: DataSources.config.dig("http", "retries"), interval: 0.2,
            backoff_factor: 2, exceptions: DataSources::HttpClient::TRANSIENT_ERRORS
          faraday.options.open_timeout = DataSources.config.dig("http", "open_timeout")
          faraday.options.timeout = @config.fetch("download_timeout", 120)
          faraday.response :raise_error
          faraday.headers["Accept"] = "application/zip"
          faraday.headers["User-Agent"] = "PropertyLens/0.1 public-data prototype"
        end
      end

      def validate_archive_key!(archive_key)
        raise ArgumentError, "Invalid cadastral archive path" if archive_key.blank? || archive_key.include?("..")
      end
    end
  end
end
