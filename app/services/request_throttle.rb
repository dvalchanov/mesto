class RequestThrottle
  STORE = ActiveSupport::Cache::MemoryStore.new

  def self.allowed?(key, limit:, period:)
    bucket = Time.current.to_i / period.to_i
    cache_key = "throttle/#{key}/#{bucket}"
    count = STORE.increment(cache_key, 1, expires_in: period + 1.second, initial: 0)
    count <= limit
  end
end
