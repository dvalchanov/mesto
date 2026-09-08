module DataSources
  class AdvisoryLock
    def self.with_lock(key)
      connection = ApplicationRecord.connection
      acquired = connection.select_value(ApplicationRecord.send(:sanitize_sql_array, [
        "SELECT pg_try_advisory_lock(hashtext(?))", key.to_s
      ]))
      raise DataCoverage::ImportAlreadyRunning, "An import is already running for #{key}" unless acquired

      yield
    ensure
      if acquired
        connection.select_value(ApplicationRecord.send(:sanitize_sql_array, [
          "SELECT pg_advisory_unlock(hashtext(?))", key.to_s
        ]))
      end
    end
  end
end
