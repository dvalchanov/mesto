class ImportCadastreArchiveJob < ApplicationJob
  queue_as :ingestion

  def perform(cadastre_source_archive_id)
    entry = CadastreSourceArchive.find(cadastre_source_archive_id)
    DataSources::PermissionGate.ensure_bulk_ingestion_allowed!(
      entry.permission_status,
      source: entry.source_archive_key
    )
    DataSources::CadastreOpenData::DistrictSynchronizer.new(
      coverage_profile: DataCoverage::Profile.find(entry.coverage_profile_key)
    ).sync_catalog_entry(entry)
  end
end
