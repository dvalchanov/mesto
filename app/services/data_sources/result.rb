module DataSources
  Result = Data.define(:status, :data, :source_url, :fetched_at, :relevant_at, :error, :raw_response) do
    def self.success(data:, source_url:, fetched_at: Time.current, relevant_at: nil, raw_response: nil)
      new(status: :success, data:, source_url:, fetched_at:, relevant_at:, error: nil, raw_response:)
    end

    def self.unavailable(source_url:, error:, fetched_at: Time.current)
      new(status: :unavailable, data: nil, source_url:, fetched_at:, relevant_at: nil, error:, raw_response: nil)
    end

    def self.failure(source_url:, error:, fetched_at: Time.current)
      new(status: :failure, data: nil, source_url:, fetched_at:, relevant_at: nil, error:, raw_response: nil)
    end

    def success? = status == :success
    def unavailable? = status == :unavailable
  end
end
