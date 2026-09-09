module DataSources
  module CadastreOpenData
    class ArchiveUnavailable < StandardError
      attr_reader :status

      def initialize(archive_key:, status:)
        @status = status
        super("The official AGKK open-data archive is not currently published for #{archive_key} (HTTP #{status})")
      end
    end

    class ArchiveTooLarge < StandardError; end

    class ArchiveClient
      DOWNLOAD_URL = "https://kais.cadastre.bg/bg/OpenData/Download".freeze

      def initialize(config: DataSources.config.dig("cadastre", "open_data"), connection: nil)
        @config = config
        @connection = connection
      end

      def download(archive_key, etag: nil, last_modified_at: nil)
        validate_archive_key!(archive_key)
        url = "#{@config.fetch('download_url', DOWNLOAD_URL)}?#{URI.encode_www_form(path: archive_key)}"
        tempfile = Tempfile.new([ "cadastre-open-data", ".zip" ])
        tempfile.binmode
        download_state = {
          io: tempfile,
          digest: Digest::SHA256.new,
          byte_size: 0
        }
        response = connection.get(url) do |request|
          request.headers["If-None-Match"] = etag if etag.present?
          request.headers["If-Modified-Since"] = last_modified_at.httpdate if last_modified_at
          request.options.context = { download_state: }
          request.options.on_data = ->(chunk, _received_bytes, _env) { write_chunk(chunk, download_state) }
        end
        unless [ 200, 304 ].include?(response.status)
          raise ArchiveUnavailable.new(archive_key:, status: response.status)
        end

        metadata = {
          checked_at: Time.current,
          etag: response.headers["etag"],
          last_modified_at: parse_time(response.headers["last-modified"]),
          checksum: download_state[:digest].hexdigest,
          byte_size: download_state[:byte_size],
          content_type: response.headers["content-type"],
          not_modified: response.status == 304
        }.compact
        if response.status == 304
          return yield nil, url, metadata.except(:checksum, :byte_size, :content_type)
        end

        tempfile.flush
        tempfile.rewind
        yield tempfile.path, url, metadata
      rescue Faraday::Error => error
        raise unless error.response_status

        raise ArchiveUnavailable.new(archive_key:, status: error.response_status), cause: error
      ensure
        tempfile&.close!
      end

      private

      def connection
        @connection ||= Faraday.new do |faraday|
          faraday.request :retry,
            max: DataSources.config.dig("http", "retries"), interval: 0.2,
            backoff_factor: 2, exceptions: DataSources::HttpClient::TRANSIENT_ERRORS,
            retry_block: method(:reset_partial_download)
          faraday.options.open_timeout = DataSources.config.dig("http", "open_timeout")
          faraday.options.timeout = @config.fetch("download_timeout", 120)
          faraday.response :raise_error
          faraday.headers["Accept"] = "application/zip"
          faraday.headers["User-Agent"] = "Mesto/0.1 public-data client (+https://mesto.bg)"
        end
      end

      def validate_archive_key!(archive_key)
        raise ArgumentError, "Invalid cadastral archive path" if archive_key.blank? || archive_key.include?("..")
      end

      def reset_partial_download(env:, **)
        download_state = env.request.context&.fetch(:download_state, nil)
        return unless download_state

        download_state.fetch(:io).rewind
        download_state.fetch(:io).truncate(0)
        download_state.fetch(:digest).reset
        download_state[:byte_size] = 0
      end

      def write_chunk(chunk, download_state)
        download_state[:byte_size] += chunk.bytesize
        if download_state[:byte_size] > @config.fetch("max_archive_bytes", 1.gigabyte).to_i
          raise ArchiveTooLarge, "The cadastral archive exceeds the configured size limit"
        end

        download_state.fetch(:digest).update(chunk)
        download_state.fetch(:io).write(chunk)
      end

      def parse_time(value)
        Time.httpdate(value) if value.present?
      rescue ArgumentError
        nil
      end
    end
  end
end
