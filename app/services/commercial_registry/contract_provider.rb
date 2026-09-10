module CommercialRegistry
  # Transport-neutral boundary for the Registry Agency's paid automated service
  # or another expressly licensed commercial interface.
  class ContractProvider < Provider
    def initialize(client:, source_url:, permission_status:)
      raise ArgumentError, "Approved automated access is required" unless permission_status == "approved"

      @client = client
      @source_url = source_url
    end

    def lookup_company(eik:)
      raise ArgumentError, "A valid EIK is required" unless BulgarianEik.valid?(eik)

      response = @client.lookup_company(eik: BulgarianEik.normalize(eik))
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
