namespace :data_sources do
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
end

namespace :property_lens do
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
    puts "report_url=http://localhost:3000/reports/#{analysis.public_token}"
    puts "status=#{analysis.status}"
    puts "successful_sources=#{analysis.source_runs.succeeded.pluck(:source_key).join(',')}"
    puts "failed_sources=#{analysis.source_runs.failed_or_unavailable.pluck(:source_key).join(',')}"
    puts "administrative_acts=#{analysis.administrative_acts.count}"
    puts "location_precision=#{analysis.location_precision}"
  end
end

namespace :cadastre do
  desc "Import an AGKK parcel, building, or individual-object open-data ZIP"
  task :import_archive, [ :archive_path, :source_archive_key, :archive_kind, :relevant_at ] => :environment do |_task, args|
    archive_path = Pathname(args[:archive_path].to_s)
    abort("Provide an existing ZIP archive path") unless archive_path.file?
    abort("Provide the official AGKK archive key") if args[:source_archive_key].blank?
    archive_kind = args[:archive_kind].to_s.to_sym
    abort("Archive kind must be parcels, buildings, or individual_objects") unless %i[parcels buildings individual_objects].include?(archive_kind)

    source_url = "#{DataSources.config.dig('cadastre', 'open_data', 'download_url')}?#{URI.encode_www_form(path: args[:source_archive_key])}"
    result = DataSources::CadastreOpenData::PropertyArchiveImporter.new(
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

  desc "Download and import AGKK parcel, building, and individual-object data for a Sofia district"
  task :sync_sofia_district, [ :district ] => :environment do |_task, args|
    abort("Provide a Sofia district name") if args[:district].blank?

    results = DataSources::CadastreOpenData::DistrictSynchronizer.new
      .sync_sofia_property_hierarchy(args[:district], identifier_level: "individual_object", force: true)
    results.each do |archive_kind, result|
      puts [ archive_kind, result.status, "seen=#{result.records_seen}", "imported=#{result.records_imported}" ].join("\t")
    end
  end
end
