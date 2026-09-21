module Analysis
  class Runner
    STAGES = %w[identifier location municipal spatial metrics report].freeze
    CALCULATION_VERSION = 3

    def initialize(
      analysis,
      cadastre_provider: Cadastre::Provider.configured,
      property_registry_provider: PropertyRegistry::Provider.configured,
      commercial_registry_provider: CommercialRegistry::Provider.configured,
      vies_provider: Vies::Provider.configured,
      coverage_profile: DataCoverage.profile
    )
      @analysis = analysis
      @cadastre_provider = cadastre_provider
      @property_registry_provider = property_registry_provider
      @commercial_registry_provider = commercial_registry_provider
      @vies_provider = vies_provider
      @coverage_profile = coverage_profile
    end

    def call
      start_analysis
      return complete_non_sofia unless @analysis.sofia?

      resolve_location
      return complete_outside_coverage if @analysis.analysis_scope_status == "outside"

      track_cadastre_ownership
      track_nag_sources
      build_property_graph
      track_property_register
      track_commercial_register
      track_vies
      track_spatial_sources
      build_property_graph
      build_report
      finish_analysis
    rescue StandardError => error
      Rails.logger.error("Property analysis #{@analysis.id} failed: #{error.class}: #{error.message}")
      @revision&.update!(status: "failed", completed_at: Time.current, error_message: error.message.truncate(500))
      @analysis.update!(status: "failed", failed_at: Time.current, failure_message: error.message.truncate(500))
      @analysis.update_progress!(current_stage || "report", "failed")
      @analysis
    end

    private

    def start_analysis
      @analysis.with_lock do
        @revision = @analysis.analysis_revisions.create!(
          number: @analysis.next_revision_number,
          status: "running",
          coverage_profile_key: @coverage_profile.key,
          calculation_version: CALCULATION_VERSION,
          started_at: Time.current
        )
        @analysis.update!(
          status: "running",
          started_at: Time.current,
          failed_at: nil,
          failure_message: nil,
          coverage_profile_key: @coverage_profile.key,
          analysis_scope_status: "unknown"
        )
      end
      STAGES.each do |stage|
        @analysis.update_progress!(stage, stage == "identifier" ? "completed" : "pending", broadcast: false)
      end
      @analysis.broadcast_progress!
      ProductEvent.record("analysis_started", property_analysis: @analysis, metadata: { revision: @revision.number })
    end

    def complete_non_sofia
      set_stage("location", "unavailable")
      set_stage("municipal", "active")
      nag_config.each do |key, config|
        record_result(key_for_nag(key), DataSources::Result.unavailable(
          source_url: config.fetch("url"),
          error: StandardError.new("Sofia municipal source does not cover this settlement")
        ))
      end
      set_stage("municipal", "unavailable")
      %w[spatial metrics].each { |stage| set_stage(stage, "unavailable") }
      set_stage("report", "active")
      coverage = CoverageBuilder.new(runs, analysis: @analysis).call
      metrics = MetricsBuilder.new(analysis: @analysis).call
      summary = ReportBuilder.new(analysis: @analysis, metrics:, coverage:).call.merge("outside_sofia" => true)
      complete_revision(status: "partial", metrics:, summary:, coverage_status: "limited")
      set_stage("report", "completed")
      ProductEvent.record("analysis_partial", property_analysis: @analysis)
      @analysis
    end

    def complete_outside_coverage
      set_stage("municipal", "unavailable")
      set_stage("spatial", "unavailable")
      set_stage("metrics", "active")
      metrics = MetricsBuilder.new(analysis: @analysis).call
      @analysis.update!(metrics:)
      set_stage("metrics", "completed")
      set_stage("report", "active")
      coverage = CoverageBuilder.new(runs, analysis: @analysis).call
      summary = ReportBuilder.new(analysis: @analysis, metrics:, coverage:).call.merge(
        "outside_development_dataset" => true,
        "coverage_profile" => profile_payload
      )
      complete_revision(status: "partial", metrics:, summary:, coverage_status: "limited")
      set_stage("report", "completed")
      ProductEvent.record("analysis_outside_coverage", property_analysis: @analysis)
      @analysis
    end

    def resolve_location
      set_stage("location", "active")
      result = @cadastre_provider.locate(identifier: @analysis.submitted_identifier, hints: {})
      record_result("cadastre", result, request_metadata: {
        identifier: @analysis.submitted_identifier,
        coverage_profile: @coverage_profile.key,
        access: "prepared_database"
      })

      if result.error.is_a?(DataCoverage::OutsideSearchCoverage)
        @analysis.update!(analysis_scope_status: "outside", location_precision: "unavailable")
        set_stage("location", "unavailable")
        return
      end

      location = LocationResolver.new(analysis: @analysis, cadastre_result: result, nag_records: []).call
      bases = location.fetch(:geometry_bases, {})
      @analysis.update!(
        centroid: location[:analysis_point] || location[:centroid],
        analysis_point: location[:analysis_point] || location[:centroid],
        subject_geometry: location[:subject_geometry],
        building_geometry: location[:building_geometry],
        parcel_geometry: location[:parcel_geometry] || location[:geometry],
        geometry_bases: bases,
        analysis_scope_status: location[:analysis_point] ? "covered" : "data_unavailable",
        location_precision: location.fetch(:precision, "unavailable")
      )
      set_stage("location", @analysis.location_point ? "completed" : "unavailable")
    end

    def track_nag_sources
      set_stage("municipal", "active")
      prepare_nag_sources
      nag_config.each do |key, config|
        source_key = key_for_nag(key)
        permission_allowed = DataSources::PermissionGate.production_use_allowed?(
          nag_config.fetch("permission_status", "review_required")
        )
        snapshot = permission_allowed && SourceSnapshot.latest_for_identifiers(
          source_key,
          identifiers: @analysis.identifiers_for_matching,
          profile: @coverage_profile
        )
        result = if !permission_allowed
          DataSources::Result.unavailable(
            source_url: config.fetch("url"),
            error: DataSources::PermissionGate::PermissionUnsettled.new(
              "Production use of #{source_key} is blocked until its permission record is approved"
            )
          )
        elsif snapshot&.status == "succeeded"
          DataSources::Result.success(
            data: {
              "record_count" => snapshot.record_count,
              "coverage_status" => snapshot.coverage_status,
              "access" => "prepared_database"
            },
            source_url: snapshot.source_url,
            fetched_at: snapshot.fetched_at || snapshot.created_at,
            relevant_at: snapshot.relevant_at
          )
        elsif snapshot
          result_method = snapshot.status == "failed" ? :failure : :unavailable
          DataSources::Result.public_send(
            result_method,
            source_url: snapshot.source_url,
            error: StandardError.new(snapshot.metadata["error_message"].presence || "The bounded NAG lookup did not complete"),
            fetched_at: snapshot.fetched_at || snapshot.created_at
          )
        else
          DataSources::Result.unavailable(
            source_url: snapshot&.source_url || config.fetch("url"),
            error: DataCoverage::DatasetNotPrepared.new("Prepared #{source_key} data is not available")
          )
        end
        record_result(source_key, result, request_metadata: { access: "prepared_database" })
      end
      status = runs.where("source_key LIKE 'nag_%'").failed_or_unavailable.exists? ? "unavailable" : "completed"
      set_stage("municipal", status)
    end

    def prepare_nag_sources
      return unless DataSources::PermissionGate.production_use_allowed?(
        nag_config.fetch("permission_status", "review_required")
      )

      enabled = ActiveModel::Type::Boolean.new.cast(
        DataSources.config.dig("nag", "on_demand_ingestion_enabled")
      )
      return unless enabled

      identifiers = @analysis.identifiers_for_matching.sort
      nag_config.each_key do |key|
        snapshot = SourceSnapshot.latest_for_identifiers(
          key_for_nag(key), identifiers:, profile: @coverage_profile
        )
        next if nag_snapshot_fresh?(snapshot)

        ImportNagRegistryJob.perform_now(key, identifiers, coverage_profile_key: @coverage_profile.key)
      rescue StandardError => error
        Rails.logger.warn("NAG #{key} preparation failed for analysis #{@analysis.id}: #{error.class}: #{error.message}")
      end
    end

    def nag_snapshot_fresh?(snapshot)
      return false unless snapshot

      age_key = snapshot.status == "succeeded" ? "successful_snapshot_max_age" : "failed_snapshot_max_age"
      max_age = DataSources.config.dig("nag", age_key).to_i.seconds
      (snapshot.fetched_at || snapshot.created_at) >= max_age.ago
    end

    def track_cadastre_ownership
      expected_keys = expected_cadastre_ownership_archive_keys
      imports = CadastreImport.where(
        source_archive_key: expected_keys,
        scope_digest: @coverage_profile.scope_digest,
        status: "succeeded"
      ).order(:completed_at).group_by(&:source_archive_key).transform_values(&:last)
      missing_keys = expected_keys - imports.keys
      if expected_keys.empty? || missing_keys.any?
        result = DataSources::Result.unavailable(
          source_url: DataSources.config.dig("cadastre", "open_data", "portal_url"),
          error: DataCoverage::DatasetNotPrepared.new(
            "Prepared AGKK legal-entity rights are not available for #{missing_keys.presence || @analysis.submitted_identifier}"
          )
        )
      else
        rights = CadastreRight.usable.for_identifiers(@analysis.identifiers_for_matching)
        result = DataSources::Result.success(
          data: {
            "record_count" => rights.count,
            "company_right_count" => rights.where(holder_entity_type: "company").count,
            "coverage_status" => "complete",
            "access" => "prepared_database",
            "archive_keys" => expected_keys,
            "natural_person_rows_omitted" => imports.values.sum do |cadastre_import|
              cadastre_import.outcome_counts["natural_person_omitted"].to_i
            end
          },
          source_url: rights.pick(:source_url) || imports.values.last.source_url,
          fetched_at: imports.values.filter_map(&:completed_at).max || Time.current,
          relevant_at: imports.values.filter_map(&:relevant_at).max
        )
      end
      record_result("cadastre_ownership", result, request_metadata: {
        identifiers: @analysis.identifiers_for_matching,
        access: "prepared_database"
      })
    end

    def expected_cadastre_ownership_archive_keys
      archive_names = DataSources::CadastreOpenData::DistrictSynchronizer::ARCHIVE_NAMES
      CadastralProperty.usable.where(cadastral_identifier: @analysis.identifiers_for_matching).filter_map do |property|
        rights_kind = "#{property.identifier_level}_rights".to_sym
        directory = property.source_archive_key.rpartition("/").first
        next if directory.blank? || !archive_names.key?(rights_kind)

        "#{directory}/#{archive_names.fetch(rights_kind)}"
      end.uniq
    end

    def build_property_graph
      @property_graph_builder = PropertyGraph::Builder.new(analysis: @analysis).call
    end

    def track_property_register
      result = @property_registry_provider.lookup(cadastral_identifier: @analysis.submitted_identifier)
      run = record_result("property_register", result, request_metadata: registry_request_metadata(result, {
        identifier: @analysis.submitted_identifier,
        access: "provider_contract"
      }))
      return unless result.success?

      PropertyRegistry::Importer.new(
        analysis: @analysis,
        payload: result.data,
        source_url: result.source_url,
        observed_at: result.fetched_at || Time.current,
        source_run: run,
        relevant_at: result.relevant_at
      ).call
    rescue StandardError => error
      mark_registry_import_failed(run, error)
    end

    def track_commercial_register
      eiks = @property_graph_builder.company_eiks
      if eiks.empty?
        result = DataSources::Result.unavailable(
          source_url: DataSources.config.dig("commercial_register", "source_url"),
          error: PublicRegistry::NoReliableIdentifier.new("No exact EIK was established by a property-related public record")
        )
        record_result("commercial_register", result, request_metadata: { access: "not_attempted_without_eik" })
        return
      end

      eiks.each do |eik|
        result = @commercial_registry_provider.lookup_company(eik:)
        run = record_result("commercial_register", result, request_metadata: registry_request_metadata(result, {
          eik:,
          access: "provider_contract"
        }))
        next unless result.success?

        CommercialRegistry::Importer.new(
          analysis: @analysis,
          payload: result.data,
          source_url: result.source_url,
          observed_at: result.fetched_at || Time.current,
          source_run: run,
          relevant_at: result.relevant_at
        ).call
      rescue StandardError => error
        mark_registry_import_failed(run, error)
      end
    end

    def track_vies
      eiks = @property_graph_builder.company_eiks
      if eiks.empty?
        result = DataSources::Result.unavailable(
          source_url: DataSources.config.dig("vies", "service_url"),
          error: PublicRegistry::NoReliableIdentifier.new("No exact EIK was established by a property-related public record")
        )
        record_result("vies", result, request_metadata: { access: "not_attempted_without_eik" })
        return
      end

      eiks.each do |eik|
        result = @vies_provider.lookup(eik:)
        run = record_result("vies", result, request_metadata: {
          eik:,
          access: "official_public_service"
        })
        next unless result.success?

        Vies::Importer.new(
          analysis: @analysis,
          payload: result.data,
          source_url: result.source_url,
          observed_at: result.fetched_at || Time.current,
          source_run: run,
          relevant_at: result.relevant_at
        ).call
      rescue StandardError => error
        mark_registry_import_failed(run, error)
      end
    end

    def mark_registry_import_failed(run, error)
      return raise(error) unless run

      run.update!(
        status: "failed",
        error_class: error.class.name,
        error_message: error.message.truncate(500)
      )
    end

    def track_spatial_sources
      set_stage("spatial", "active")
      track_planning_datasets
      track_sofiaplan_datasets
      track_openstreetmap_dataset
      spatial_runs = runs.where(
        "source_key LIKE 'arcgis_%' OR source_key LIKE 'sofiaplan_dataset_%' OR source_key LIKE 'openstreetmap_%'"
      )
      set_stage("spatial", spatial_runs.succeeded.exists? ? "completed" : "unavailable")
    end

    def track_planning_datasets
      arcgis_config.each do |key, config|
        source_key = "arcgis_#{key}"
        dataset = SpatialDataset.usable.find_by(key: source_key, coverage_profile_key: @coverage_profile.key)
        result = prepared_planning_result(dataset, config)
        record_result(source_key, result, request_metadata: {
          access: "prepared_database",
          geometry_basis: @analysis.parcel_geometry ? "parcel_polygon" : "unavailable"
        })
      end
    end

    def prepared_planning_result(dataset, config)
      return dataset_unavailable(config.fetch("url"), "Prepared planning dataset has not been imported") unless dataset
      return dataset_unavailable(dataset.source_url, "A cadastral parcel polygon is required") unless @analysis.parcel_geometry

      features = dataset.spatial_features.intersecting(@analysis.parcel_geometry).map do |feature|
        {
          "type" => "Feature",
          "geometry" => RGeo::GeoJSON.encode(feature.geometry),
          "properties" => feature.properties
        }
      end
      DataSources::Result.success(
        data: {
          "type" => "FeatureCollection",
          "features" => features,
          "coverage_status" => dataset.coverage_status,
          "access" => "prepared_database"
        },
        source_url: dataset.source_url,
        fetched_at: dataset.last_imported_at,
        relevant_at: dataset.relevant_at
      )
    end

    def track_sofiaplan_datasets
      DataSources.config.dig("sofiaplan", "datasets").each do |key, config|
        dataset = SpatialDataset.usable.find_by(key:, coverage_profile_key: @coverage_profile.key)
        result = if dataset && @analysis.location_point
          DataSources::Result.success(
            data: {
              "category" => key,
              "feature_count" => dataset.spatial_features.count,
              "coverage_status" => dataset.coverage_status,
              "access" => "prepared_database"
            },
            source_url: dataset.source_url,
            fetched_at: dataset.last_imported_at,
            relevant_at: dataset.relevant_at
          )
        else
          dataset_unavailable(
            dataset&.source_url || "#{DataSources.config.dig('sofiaplan', 'base_url')}/datasets/#{config.fetch('id')}",
            dataset ? "A reliable location is required" : "Configured dataset has not been imported"
          )
        end
        record_result("sofiaplan_dataset_#{key}", result, request_metadata: { access: "prepared_database" })
      end
    end

    def track_openstreetmap_dataset
      config = DataSources.config.fetch("openstreetmap")
      dataset = SpatialDataset.usable.find_by(
        key: config.fetch("dataset_key"),
        coverage_profile_key: @coverage_profile.key
      )
      result = if dataset && @analysis.location_point
        DataSources::Result.success(
          data: {
            "feature_count" => dataset.spatial_features.count,
            "coverage_status" => dataset.coverage_status,
            "access" => "prepared_database"
          },
          source_url: dataset.source_url,
          fetched_at: dataset.last_imported_at,
          relevant_at: dataset.relevant_at
        )
      else
        dataset_unavailable(
          dataset&.source_url || config.fetch("overpass_url"),
          dataset ? "A reliable location is required" : "Prepared OpenStreetMap amenities have not been imported"
        )
      end
      record_result("openstreetmap_nearby_amenities", result, request_metadata: {
        access: "prepared_database",
        radius_m: DataSources::OpenStreetMap::NearbyAmenitiesClient::RADIUS_METRES,
        geometry_basis: @analysis.geometry_bases["amenity_proximity"]
      })
    end

    def build_report
      set_stage("metrics", "active")
      metrics = MetricsBuilder.new(analysis: @analysis).call
      @analysis.update!(metrics:)
      set_stage("metrics", "completed")

      set_stage("report", "active")
      coverage = CoverageBuilder.new(runs, analysis: @analysis).call
      summary = ReportBuilder.new(analysis: @analysis, metrics:, coverage:).call.merge(
        "coverage_profile" => profile_payload
      )
      @analysis.update!(coverage_status: coverage.fetch("status"), summary:)
      set_stage("report", "completed")
    end

    def finish_analysis
      blocking_runs = runs.where.not(source_key: CoverageBuilder::NON_BLOCKING_SOURCE_KEYS)
      status = if blocking_runs.failed_or_unavailable.exists? || @analysis.coverage_status != "complete"
        "partial"
      else
        "ready"
      end
      complete_revision(
        status:,
        metrics: @analysis.metrics,
        summary: @analysis.summary,
        coverage_status: @analysis.coverage_status
      )
      ProductEvent.record(status == "partial" ? "analysis_partial" : "analysis_completed", property_analysis: @analysis)
      @analysis
    end

    def complete_revision(status:, metrics:, summary:, coverage_status:)
      completed_at = Time.current
      @analysis.update!(status:, coverage_status:, metrics:, summary:, completed_at:)
      @revision.update!(
        status:,
        completed_at:,
        geometry_bases: @analysis.geometry_bases,
        dataset_revisions: dataset_revisions,
        report_snapshot: { "summary" => summary, "metrics" => metrics }
      )
    end

    def dataset_revisions
      PreparedDataRevisionSet.call(
        profile: @coverage_profile,
        identifiers: @analysis.identifiers_for_matching
      )
    end

    def record_result(source_key, result, request_metadata: {})
      payload = serializable_payload(result.data)
      @analysis.source_runs.create!(
        analysis_revision: @revision,
        source_key:,
        status: result.success? ? "succeeded" : result.unavailable? ? "unavailable" : "failed",
        request_metadata:,
        parsed_payload: payload || {},
        source_url: result.source_url,
        fetched_at: result.fetched_at,
        relevant_at: result.relevant_at,
        checksum: payload ? Digest::SHA256.hexdigest(JSON.generate(payload)) : nil,
        error_class: result.error&.class&.name,
        error_message: result.error&.message&.truncate(500),
        raw_response: Rails.application.config.x.store_raw_source_responses ? result.raw_response : nil
      )
    end

    def registry_request_metadata(result, metadata)
      data = result.data.respond_to?(:to_h) ? result.data.to_h.with_indifferent_access : {}
      return metadata unless ActiveModel::Type::Boolean.new.cast(data[:demo_data])

      metadata.merge(demo_data: true, access: "synthetic_demo_provider")
    end

    def serializable_payload(data)
      return if data.nil?

      JSON.parse(JSON.generate(serializable_value(data)))
    rescue JSON::GeneratorError
      { "available" => true }
    end

    def serializable_value(value)
      case value
      when Hash then value.transform_values { |child| serializable_value(child) }
      when Array then value.map { |child| serializable_value(child) }
      else
        RGeo::Feature::Instance === value ? RGeo::GeoJSON.encode(value) : value
      end
    end

    def dataset_unavailable(source_url, message)
      DataSources::Result.unavailable(
        source_url:,
        error: DataCoverage::DatasetNotPrepared.new(message)
      )
    end

    def profile_payload
      {
        "key" => @coverage_profile.key,
        "label" => @coverage_profile.label,
        "search_boundary" => RGeo::GeoJSON.encode(@coverage_profile.search_geometry),
        "supporting_buffer_metres" => @coverage_profile.supporting_buffer_metres
      }
    end

    def runs = @revision.source_runs
    def set_stage(key, status)
      @current_stage = key
      @analysis.update_progress!(key, status)
    end
    def current_stage = @current_stage
    def key_for_nag(key) = "nag_#{key}"
    def nag_config = DataSources.config.dig("nag", "registers")
    def arcgis_config = DataSources.config.fetch("arcgis")
  end
end
