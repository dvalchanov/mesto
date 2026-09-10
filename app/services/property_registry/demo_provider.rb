module PropertyRegistry
  # Synthetic provider for exercising the complete registry graph in development.
  # It never performs network requests and refuses to initialize in production.
  class DemoProvider < Provider
    def initialize(config: DataSources.config.fetch("property_register"), environment: Rails.env)
      raise ArgumentError, "Registry demo data is restricted to development and test" unless environment.development? || environment.test?

      @config = config
    end

    def lookup(cadastral_identifier:)
      unless cadastral_identifier.to_s == @config.fetch("demo_identifier")
        return DataSources::Result.unavailable(
          source_url: @config.fetch("demo_source_url"),
          error: PublicRegistry::DemoRecordUnavailable.new(
            "No synthetic Property Register record is configured for #{cadastral_identifier}"
          )
        )
      end

      DataSources::Result.success(
        data: {
          demo_data: true,
          property_identifier: cadastral_identifier,
          coverage: { complete_history: false, limitation: "synthetic_demo_data" },
          owners: [
            {
              legal_name: "[ДЕМО] МЕСТО ИМОТИ ЕООД",
              eik: @config.fetch("demo_company_eik"),
              current: true,
              valid_from: "2024-05-20",
              source_record_reference: "DEMO-PR-CURRENT-001",
              source_date: "2026-09-01"
            },
            {
              name: "[ДЕМО] Предишен вписан собственик",
              current: false,
              valid_from: "2019-02-14",
              valid_until: "2024-05-19",
              source_record_reference: "DEMO-PR-HISTORICAL-001",
              source_date: "2024-05-19"
            }
          ]
        },
        source_url: @config.fetch("demo_source_url"),
        fetched_at: Time.current,
        relevant_at: Time.zone.parse("2026-09-01")
      )
    end
  end
end
