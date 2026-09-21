module DataSources
  class PermissionGate
    class PermissionUnsettled < StandardError; end

    def self.production_use_allowed?(permission_status)
      !Rails.env.production? || permission_status == "approved"
    end

    def self.ensure_bulk_ingestion_allowed!(permission_status, source:)
      return if production_use_allowed?(permission_status)

      raise PermissionUnsettled,
        "Production bulk ingestion for #{source} requires an approved permission record"
    end
  end
end
