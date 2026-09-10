class ImportNagRegistryJob < ApplicationJob
  queue_as :ingestion

  def perform(registry_kind, identifiers, coverage_profile_key: DataCoverage.profile.key)
    DataSources::PermissionGate.ensure_bulk_ingestion_allowed!(
      config.fetch("permission_status", "review_required"),
      source: "NAG #{registry_kind}"
    )
    identifiers = Array(identifiers).compact.map(&:to_s).uniq.sort
    registry_config = config.fetch("registers").fetch(registry_kind.to_s)
    result = DataSources::Nag::RegistryClient.new(
      registry_kind: registry_kind.to_s,
      config: registry_config
    ).search(identifiers: Array(identifiers))

    if result.success?
      records = result.data
      records.each { |record| DataSources::Nag::AdministrativeActImporter.call(record) }
      record_snapshot(result, coverage_profile_key, registry_kind, records.length, identifiers)
    else
      record_snapshot(result, coverage_profile_key, registry_kind, 0, identifiers)
      raise result.error
    end
  end

  private

  def record_snapshot(result, profile_key, registry_kind, record_count, identifiers)
    SourceSnapshot.create!(
      source_key: "nag_#{registry_kind}",
      provider: "НАГ Столична община",
      source_url: result.source_url,
      coverage_profile_key: profile_key,
      status: result.success? ? "succeeded" : result.unavailable? ? "unavailable" : "failed",
      coverage_status: result.success? ? "complete" : "unknown",
      record_count:,
      fetched_at: result.fetched_at,
      relevant_at: result.relevant_at,
      permission_status: DataSources.config.dig("nag", "permission_status"),
      metadata: {
        "acquisition_method" => "bounded_identifier_search",
        "searched_identifiers" => Array(identifiers),
        "completeness_note" => "Not an area-wide or historically complete register feed",
        "error_class" => result.error&.class&.name,
        "error_message" => result.error&.message&.truncate(500),
        "storage_reuse" => config["storage_reuse"],
        "redistribution" => config["redistribution"],
        "retention_constraints" => config["retention_constraints"],
        "rate_limit" => config["rate_limit"]
      }
    )
  end

  def config
    @config ||= DataSources.config.fetch("nag")
  end
end
