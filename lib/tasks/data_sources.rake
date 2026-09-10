namespace :data_sources do
  desc "Populate every shared spatial source for the current coverage profile"
  task prepare_spatial: :environment do
    DataSources::Sofiaplan::DatasetSynchronizer.new.sync.each do |key, result|
      puts [ "sofiaplan", key, result.status, result.try(:records_seen) ].compact.join("\t")
    end
    DataSources::ArcGis::DatasetSynchronizer.new.sync.each do |key, result|
      puts [ "arcgis", key, result.status, result.try(:records_seen) ].compact.join("\t")
    end
    result = DataSources::OpenStreetMap::DatasetSynchronizer.new.sync
    puts [ "openstreetmap", result.status, result.try(:records_seen) ].compact.join("\t")
  end

  desc "Enqueue refresh checks for prepared datasets"
  task refresh_due: :environment do
    RefreshPreparedDataJob.perform_later(coverage_profile_key: DataCoverage.profile.key)
    puts "enqueued profile=#{DataCoverage.profile.key}"
  end

  desc "Check configured public-source connectivity"
  task check: :environment do
    checks = {}
    catalog = DataSources::Sofiaplan::CatalogClient.new
    checks["sofiaplan_version"] = catalog.version
    checks["sofiaplan_catalog"] = catalog.datasets
    DataSources.config.dig("sofiaplan", "datasets").each do |key, config|
      dataset = SpatialDataset.find_by(key:)
      checks["sofiaplan_dataset_#{key}"] = if dataset&.last_imported_at
        DataSources::Result.success(
          data: { feature_count: dataset.spatial_features.count, dataset_id: config.fetch("id") },
          source_url: dataset.source_url,
          fetched_at: dataset.last_imported_at,
          relevant_at: dataset.relevant_at
        )
      else
        DataSources::Result.unavailable(
          source_url: "#{DataSources.config.dig("sofiaplan", "base_url")}/datasets/#{config.fetch("id")}",
          error: StandardError.new("not imported")
        )
      end
    end

    DataSources.config.dig("arcgis").each do |key, config|
      checks["arcgis_#{key}"] = DataSources::ArcGis::FeatureLayerClient.new(layer_url: config.fetch("url")).metadata
    end

    DataSources.config.dig("nag", "registers").each do |key, config|
      begin
        data = if DataSources.fixture?
          { fixture_records: DataSources::Nag::RegistryParser.new(registry_kind: key, base_url: config.fetch("url")).parse(DataSources::FixtureLoader.read("nag_#{key}_search.html")).length }
        else
          { status: DataSources::HttpClient.new.get(config.fetch("url")).status }
        end
        checks["nag_#{key}"] = DataSources::Result.success(data:, source_url: config.fetch("url"))
      rescue StandardError => error
        checks["nag_#{key}"] = DataSources::Result.unavailable(source_url: config.fetch("url"), error:)
      end
    end

    checks.each do |key, result|
      imported = SpatialDataset.find_by(key: key.delete_prefix("sofiaplan_dataset_"))&.last_imported_at
      detail = result.success? ? result.data.to_s.truncate(100) : result.error.message
      puts [ key, result.status, "latest_import=#{imported || '-'}", detail ].join("\t")
    end
  end
end

namespace :sofiaplan do
  desc "List SofiaPlan datasets, optionally filtered by a search term"
  task :datasets, [ :term ] => :environment do |_task, args|
    result = DataSources::Sofiaplan::CatalogClient.new.datasets
    abort("SofiaPlan catalog unavailable: #{result.error.message}") unless result.success?

    term = args[:term].to_s.downcase
    result.data.each do |dataset|
      haystack = dataset.values_at("name", "description", "category", "provider").compact.join(" ").downcase
      next if term.present? && !haystack.include?(term)

      puts [ dataset["id"], dataset["name"], dataset["provider"], dataset["relevant_at"], dataset["description"] ].join("\t")
    end
  end

  desc "Import the configured, pinned SofiaPlan datasets"
  task :sync, [ :key ] => :environment do |_task, args|
    DataSources::Sofiaplan::DatasetSynchronizer.new.sync(args[:key]).each do |key, result|
      if result.is_a?(DatasetImport)
        puts [ key, result.status, "seen=#{result.records_seen}", "created=#{result.records_created}", "updated=#{result.records_updated}", "removed=#{result.records_removed}" ].join("\t")
      else
        puts [ key, result.status, result.error.message ].join("\t")
      end
    end
  end

  desc "Replay retained SofiaPlan snapshots without contacting the upstream API"
  task :replay_retained, [ :key ] => :environment do |_task, args|
    DataSources::Sofiaplan::DatasetSynchronizer.new.replay(args[:key]).each do |key, result|
      puts [ key, result.status, result.try(:records_seen) ].compact.join("\t")
    end
  end
end

namespace :arcgis do
  desc "Import configured planning layers for the current coverage profile"
  task :sync, [ :key ] => :environment do |_task, args|
    results = DataSources::ArcGis::DatasetSynchronizer.new.sync(args[:key])
    results.each { |key, result| puts [ key, result.status, result.try(:records_seen) ].compact.join("\t") }
  end


  desc "Replay retained ArcGIS snapshots without contacting the upstream API"
  task :replay_retained, [ :key ] => :environment do |_task, args|
    results = DataSources::ArcGis::DatasetSynchronizer.new.replay(args[:key])
    results.each { |key, result| puts [ key, result.status, result.try(:records_seen) ].compact.join("\t") }
  end
end

namespace :openstreetmap do
  desc "Import schools and kindergartens for the supporting-data boundary"
  task sync: :environment do
    result = DataSources::OpenStreetMap::DatasetSynchronizer.new.sync
    puts [ result.status, result.try(:records_seen) ].compact.join("\t")
  end


  desc "Replay the retained OpenStreetMap snapshot without contacting Overpass"
  task replay_retained: :environment do
    result = DataSources::OpenStreetMap::DatasetSynchronizer.new.replay
    puts [ result.status, result.try(:records_seen) ].compact.join("\t")
  end
end

namespace :coverage do
  desc "Show configured boundaries, prepared datasets, archive health, and permission states"
  task status: :environment do
    profile = DataCoverage.profile
    puts "profile=#{profile.key}\tlabel=#{profile.label}\tmode=#{profile.mode}\tbuffer_m=#{profile.supporting_buffer_metres}"
    puts "search_boundary=#{profile.search_geometry_wkt}"
    CadastreSourceArchive.for_profile(profile).order(:district, :object_kind).each do |entry|
      latest = entry.latest_successful_import
      puts [
        "cadastre", entry.district, entry.object_kind, entry.status,
        "enabled=#{entry.enabled?}", "permission=#{entry.permission_status}",
        "checked=#{entry.last_checked_at || '-'}", "imported=#{latest&.completed_at || '-'}",
        "seen=#{latest&.records_seen || 0}", "outcomes=#{latest&.outcome_counts || {}}"
      ].join("\t")
    end
    SpatialDataset.where(coverage_profile_key: profile.key).order(:key).each do |dataset|
      latest = dataset.dataset_imports.order(created_at: :desc).first
      puts [
        "spatial", dataset.key, "coverage=#{dataset.coverage_status}",
        "permission=#{dataset.permission_status}", "imported=#{dataset.last_imported_at || '-'}",
        "features=#{dataset.spatial_features.count}", "outcomes=#{latest&.outcome_counts || {}}"
      ].join("\t")
    end
    SourceSnapshot.for_profile(profile).order(:source_key, created_at: :desc).each do |snapshot|
      puts [
        "snapshot", snapshot.source_key, snapshot.status,
        "coverage=#{snapshot.coverage_status}", "permission=#{snapshot.permission_status}",
        "fetched=#{snapshot.fetched_at || '-'}", "records=#{snapshot.record_count}"
      ].join("\t")
    end
  end
end

namespace :mesto do
  desc "Run a property analysis synchronously"
  task :analyze, [ :identifier ] => :environment do |_task, args|
    identifier = CadastralIdentifier.new(args[:identifier])
    abort("Invalid cadastral identifier") unless identifier.valid?

    analysis = PropertyAnalysis.create!(
      submitted_identifier: identifier.to_s,
      settlement_code: identifier.settlement_code,
      parcel_identifier: identifier.parcel_identifier,
      building_identifier: identifier.building_identifier,
      individual_object_identifier: identifier.individual_object_identifier,
      identifier_level: identifier.level.to_s
    )
    Analysis::Runner.new(analysis).call
    analysis.reload
    puts "report_url=http://mesto.localhost/reports/#{analysis.public_token}"
    puts "status=#{analysis.status}"
    puts "successful_sources=#{analysis.source_runs.succeeded.pluck(:source_key).join(',')}"
    puts "failed_sources=#{analysis.source_runs.failed_or_unavailable.pluck(:source_key).join(',')}"
    puts "administrative_acts=#{analysis.administrative_acts.count}"
    puts "location_precision=#{analysis.location_precision}"
  end
end

namespace :cadastre do
  desc "Create source-archive catalog entries for the current coverage profile"
  task catalog: :environment do
    DataSources::CadastreOpenData::SourceCatalog.new.ensure_profile_entries!.each do |entry|
      puts [ entry.id, entry.district, entry.object_kind, entry.enabled? ? "enabled" : "disabled", entry.source_archive_key ].join("\t")
    end
  end

  desc "Create disabled source-archive entries for one explicit Sofia district"
  task :catalog_district, [ :district ] => :environment do |_task, args|
    abort("Provide a district name") if args[:district].blank?

    entries = DataSources::CadastreOpenData::SourceCatalog.new.ensure_district_entries!(args[:district])
    entries.each { |entry| puts [ entry.id, entry.district, entry.object_kind, entry.source_archive_key ].join("\t") }
  end

  desc "Record an explicit source-permission approval for a catalog district"
  task :approve_district_permissions, [ :district, :reference ] => :environment do |_task, args|
    abort("Provide a district and supporting permission reference") if args[:district].blank? || args[:reference].blank?

    entries = CadastreSourceArchive.for_profile(DataCoverage.profile).where(district: args[:district])
    abort("Catalog the district first") if entries.empty?
    entries.update_all(
      permission_status: "approved",
      permission_reference: args[:reference],
      updated_at: Time.current
    )
    puts "approved=#{entries.count}\tdistrict=#{args[:district]}\treference=#{args[:reference]}"
  end

  desc "Enqueue enabled archive imports for the current coverage profile"
  task sync_profile: :environment do
    profile = DataCoverage.profile
    entries = DataSources::CadastreOpenData::SourceCatalog.new.ensure_profile_entries!
    entries = entries.select(&:enabled?) if profile.mode == "catalog"
    entries.each { |entry| ImportCadastreArchiveJob.perform_later(entry.id) }
    puts "enqueued=#{entries.length}\tprofile=#{profile.key}"
  end

  desc "Enable a reviewed catalog district for production search coverage"
  task :enable_district, [ :district ] => :environment do |_task, args|
    abort("Provide a district name") if args[:district].blank?

    entries = CadastreSourceArchive.for_profile(DataCoverage.profile).where(district: args[:district])
    abort("Run cadastre:catalog or configure this district first") if entries.empty?
    abort("Approve and document source permissions before enabling this district") if entries.where.not(permission_status: "approved").exists?

    entries.update_all(enabled: true, updated_at: Time.current)
    puts "enabled=#{entries.count}\tdistrict=#{args[:district]}"
  end

  desc "Preview or explicitly prune cadastral rows outside the supporting-data boundary"
  task :prune_outside_scope, [ :confirmation ] => :environment do |_task, args|
    profile = DataCoverage.profile
    relation = CadastralProperty.where.not(geometry: nil).where(
      "NOT ST_Intersects(geometry, ST_GeomFromText(?, 4326))",
      profile.supporting_geometry_wkt
    )
    puts "profile=#{profile.key}\toutside_rows=#{relation.count}"
    if args[:confirmation] == "DELETE"
      deleted = relation.delete_all
      puts "deleted=#{deleted}\trecoverable_from_source_archives=true"
    else
      puts "dry_run=true\tto_delete=bin/rails 'cadastre:prune_outside_scope[DELETE]'"
    end
  end

  desc "Import an AGKK geometry or legal-entity-rights open-data ZIP"
  task :import_archive, [ :archive_path, :source_archive_key, :archive_kind, :relevant_at ] => :environment do |_task, args|
    archive_path = Pathname(args[:archive_path].to_s)
    abort("Provide an existing ZIP archive path") unless archive_path.file?
    abort("Provide the official AGKK archive key") if args[:source_archive_key].blank?
    archive_kind = args[:archive_kind].to_s.to_sym
    allowed_kinds = DataSources::CadastreOpenData::DistrictSynchronizer::ARCHIVE_NAMES.keys
    abort("Unknown AGKK archive kind") unless allowed_kinds.include?(archive_kind)

    source_url = "#{DataSources.config.dig('cadastre', 'open_data', 'download_url')}?#{URI.encode_www_form(path: args[:source_archive_key])}"
    importer_class = if DataSources::CadastreOpenData::DistrictSynchronizer::OWNERSHIP_ARCHIVE_KINDS.include?(archive_kind)
      DataSources::CadastreOpenData::OwnershipArchiveImporter
    else
      DataSources::CadastreOpenData::PropertyArchiveImporter
    end
    result = importer_class.new(
      archive_path:, source_archive_key: args[:source_archive_key], source_url:, archive_kind:,
      relevant_at: args[:relevant_at].presence && Time.zone.parse(args[:relevant_at])
    ).call
    puts [ result.status, "seen=#{result.records_seen}", "imported=#{result.records_imported}" ].join("\t")
  end

  desc "Import AGKK individual-object open data from a local ZIP archive"
  task :import_individual_objects, [ :archive_path, :source_archive_key, :relevant_at ] => :environment do |_task, args|
    archive_path = Pathname(args[:archive_path].to_s)
    abort("Provide an existing ZIP archive path") unless archive_path.file?
    abort("Provide the official AGKK archive key") if args[:source_archive_key].blank?

    source_url = "#{DataSources.config.dig('cadastre', 'open_data', 'download_url')}?#{URI.encode_www_form(path: args[:source_archive_key])}"
    result = DataSources::CadastreOpenData::IndividualObjectsImporter.new(
      archive_path:, source_archive_key: args[:source_archive_key], source_url:,
      relevant_at: args[:relevant_at].presence && Time.zone.parse(args[:relevant_at])
    ).call
    puts [ result.status, "seen=#{result.records_seen}", "imported=#{result.records_imported}" ].join("\t")
  end

  desc "Download and import AGKK property hierarchy and legal-entity rights for a Sofia district"
  task :sync_sofia_district, [ :district ] => :environment do |_task, args|
    abort("Provide a Sofia district name") if args[:district].blank?

    results = DataSources::CadastreOpenData::DistrictSynchronizer.new
      .sync_sofia_property_hierarchy(args[:district], identifier_level: "individual_object", force: true)
    results.each do |archive_kind, result|
      puts [ archive_kind, result.status, "seen=#{result.records_seen}", "imported=#{result.records_imported}" ].join("\t")
    end
  end

  desc "Replay the latest retained S3 archive for one catalog entry"
  task :replay_retained, [ :catalog_entry_id ] => :environment do |_task, args|
    entry = CadastreSourceArchive.find(args[:catalog_entry_id])
    profile = DataCoverage::Profile.find(entry.coverage_profile_key)
    result = DataSources::CadastreOpenData::DistrictSynchronizer.new(coverage_profile: profile)
      .replay_catalog_entry(entry)
    puts [ result.status, "seen=#{result.records_seen}", "imported=#{result.records_imported}" ].join("\t")
  end
end
