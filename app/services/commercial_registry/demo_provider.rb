module CommercialRegistry
  # Synthetic provider for exercising exact-EIK company enrichment in development.
  # It never performs network requests and refuses to initialize in production.
  class DemoProvider < Provider
    def initialize(config: DataSources.config.fetch("commercial_register"), environment: Rails.env)
      raise ArgumentError, "Registry demo data is restricted to development and test" unless environment.development? || environment.test?

      @config = config
    end

    def lookup_company(eik:)
      normalized_eik = BulgarianEik.normalize(eik)
      unless normalized_eik == @config.fetch("demo_company_eik")
        return DataSources::Result.unavailable(
          source_url: @config.fetch("demo_source_url"),
          error: PublicRegistry::DemoRecordUnavailable.new(
            "No synthetic Commercial Register record is configured for EIK #{normalized_eik}"
          )
        )
      end

      DataSources::Result.success(
        data: {
          demo_data: true,
          company: {
            legal_name: "[ДЕМО] МЕСТО ИМОТИ ЕООД",
            eik: normalized_eik,
            status: "active",
            registration_date: "2019-01-10",
            legal_form: "ЕООД",
            liquidation_status: "none",
            insolvency_status: "none",
            source_record_reference: "DEMO-CR-COMPANY-000000000",
            source_date: "2026-09-01",
            material_circumstances: [
              {
                type: "manager_change",
                status: "registered",
                date: "2024-06-01",
                description: "[ДЕМО] Вписана промяна на управител"
              }
            ]
          },
          managers: [
            {
              name: "[ДЕМО] Текущ управител",
              current: true,
              valid_from: "2024-06-01",
              source_record_reference: "DEMO-CR-MANAGER-CURRENT"
            },
            {
              name: "[ДЕМО] Предишен управител",
              current: false,
              valid_from: "2019-01-10",
              valid_until: "2024-05-31",
              source_record_reference: "DEMO-CR-MANAGER-HISTORICAL"
            }
          ],
          owners: [
            {
              name: "[ДЕМО] Едноличен собственик на капитала",
              current: true,
              ownership_percentage: "100",
              source_record_reference: "DEMO-CR-CAPITAL-OWNER"
            }
          ],
          beneficial_owners: [
            {
              name: "[ДЕМО] Действителен собственик",
              current: true,
              control_basis: "[ДЕМО] Пряк контрол",
              source_record_reference: "DEMO-CR-BENEFICIAL-OWNER"
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
