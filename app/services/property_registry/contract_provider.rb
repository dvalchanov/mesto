module PropertyRegistry
  # Adapter for a future interface that Mesto is contractually and legally entitled to use.
  # The injected client owns transport/authentication; this class never automates portal credentials.
  class ContractProvider < Provider
    def initialize(client:, source_url:, permission_status:)
      raise ArgumentError, "Approved automated access is required" unless permission_status == "approved"

      @client = client
      @source_url = source_url
    end

    def lookup(cadastral_identifier:)
      response = @client.lookup_property(cadastral_identifier:)
      DataSources::Result.success(
        data: response.fetch(:data),
        raw_response: response[:raw_response],
        source_url: response[:source_url] || @source_url,
        fetched_at: response[:fetched_at] || Time.current,
        relevant_at: response[:relevant_at]
      )
    rescue StandardError => error
      DataSources::Result.failure(source_url: @source_url, error:)
    end
  end
end
