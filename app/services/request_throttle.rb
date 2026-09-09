class RequestThrottle
  def self.allowed?(key, limit:, period:)
    bucket = Time.current.to_i / period.to_i
    cache_key = "throttle/#{key}/#{bucket}"
    count = store.increment(cache_key, 1, expires_in: period + 1.second)
    count.present? && count <= limit
  end

  def self.store
    return Rails.cache if Rails.env.production?

    @local_store ||= ActiveSupport::Cache::MemoryStore.new
  end
end
