module DataSources
  class PermissionGate
    class PermissionUnsettled < StandardError; end

    def self.ensure_bulk_ingestion_allowed!(permission_status, source:)
      return unless Rails.env.production?
      return if permission_status == "approved"

      raise PermissionUnsettled,
        "Production bulk ingestion for #{source} requires an approved permission record"
    end
  end
end
