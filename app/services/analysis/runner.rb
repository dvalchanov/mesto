module Analysis
  class Runner
    STAGES = %w[identifier municipal location spatial metrics report].freeze

    def initialize(analysis, cadastre_provider: Cadastre::Provider.configured)
      @analysis = analysis
      @cadastre_provider = cadastre_provider
      @nag_records = []
    end

    def call
      start_analysis
      return complete_non_sofia unless @analysis.sofia?

      run_nag_sources
      resolve_location
      run_spatial_sources
      build_report
      finish_analysis
    rescue StandardError => error
      Rails.logger.error("Property analysis #{@analysis.id} failed: #{error.class}: #{error.message}")
      @analysis.update!(status: "failed", failed_at: Time.current, failure_message: error.message.truncate(500))
      @analysis.update_progress!(current_stage || "report", "failed")
      @analysis
    end

    private

    def start_analysis
      @analysis.update!(status: "running", started_at: Time.current, failed_at: nil, failure_message: nil)
      STAGES.each { |stage| @analysis.update_progress!(stage, stage == "identifier" ? "completed" : "pending") }
      ProductEvent.record("analysis_started", property_analysis: @analysis)
    end

    def complete_non_sofia
      set_stage("municipal", "active")
      nag_config.each do |key, config|
        record_result(key, DataSources::Result.unavailable(source_url: config.fetch("url"), error: StandardError.new("Sofia municipal source does not cover this settlement")))
      end
      set_stage("municipal", "unavailable")
      %w[location spatial metrics].each { |stage| set_stage(stage, "unavailable") }
      set_stage("report", "active")
      coverage = CoverageBuilder.new(@analysis.source_runs, analysis: @analysis).call
      metrics = MetricsBuilder.new(analysis: @analysis).call
      summary = ReportBuilder.new(analysis: @analysis, metrics:, coverage:).call.merge("outside_sofia" => true)
      @analysis.update!(status: "partial", coverage_status: "limited", metrics:, summary:, completed_at: Time.current)
      set_stage("report", "completed")
      ProductEvent.record("analysis_partial", property_analysis: @analysis)
      @analysis
    end

    def run_nag_sources
      set_stage("municipal", "active")
      nag_config.each do |key, config|
        result = DataSources::Nag::RegistryClient.new(registry_kind: key, config:).search(
          identifiers: @analysis.identifiers_for_matching
        )
        record_result("nag_#{key}", result, request_metadata: { identifiers: @analysis.identifiers_for_matching })
        next unless result.success?

        @nag_records.concat(result.data)
        result.data.each { |record| persist_act(record) }
      end
      status = @analysis.source_runs.where("source_key LIKE 'nag_%'").succeeded.exists? ? "completed" : "failed"
      set_stage("municipal", status)
    end

    def resolve_location
      set_stage("location", "active")
      result = @cadastre_provider.locate(
        identifier: @analysis.submitted_identifier,
        hints: { district: cadastre_district_hint }
      )
      record_result("cadastre", result, request_metadata: { identifier: @analysis.submitted_identifier })
      location = LocationResolver.new(analysis: @analysis, cadastre_result: result, nag_records: @nag_records).call
      @analysis.update!(
        centroid: location[:centroid], parcel_geometry: location[:geometry],
        location_precision: location.fetch(:precision, "unavailable")
      )
      set_stage("location", @analysis.centroid ? "completed" : "unavailable")
    end

    def run_spatial_sources
      set_stage("spatial", "active")
      if @analysis.centroid
        arcgis_config.each do |key, config|
          result = DataSources::ArcGis::FeatureLayerClient.new(layer_url: config.fetch("url")).query(geometry: @analysis.centroid)
          record_result("arcgis_#{key}", result, request_metadata: { precision: @analysis.location_precision })
        end
      else
        arcgis_config.each do |key, config|
          record_result("arcgis_#{key}", DataSources::Result.unavailable(
            source_url: config.fetch("url"), error: StandardError.new("A reliable location is required")
          ))
        end
      end
      import_missing_spatial_datasets if @analysis.centroid
      track_spatial_datasets
      spatial_success = @analysis.source_runs.where("source_key LIKE 'arcgis_%' OR source_key LIKE 'sofiaplan_dataset_%'").succeeded.exists?
      set_stage("spatial", spatial_success ? "completed" : "unavailable")
    end

    def build_report
      set_stage("metrics", "active")
      metrics = MetricsBuilder.new(analysis: @analysis).call
      @analysis.update!(metrics:)
      set_stage("metrics", "completed")

      set_stage("report", "active")
      coverage = CoverageBuilder.new(@analysis.source_runs, analysis: @analysis).call
      summary = ReportBuilder.new(analysis: @analysis, metrics:, coverage:).call
      @analysis.update!(coverage_status: coverage.fetch("status"), summary:)
      set_stage("report", "completed")
    end

    def finish_analysis
      partial = @analysis.source_runs.failed_or_unavailable.exists?
      status = partial ? "partial" : "ready"
      @analysis.update!(status:, completed_at: Time.current)
      ProductEvent.record(partial ? "analysis_partial" : "analysis_completed", property_analysis: @analysis)
      @analysis
    end

    def track_spatial_datasets
      DataSources.config.dig("sofiaplan", "datasets").each do |key, config|
        dataset = SpatialDataset.find_by(key:)
        result = if !@analysis.centroid
          DataSources::Result.unavailable(
            source_url: dataset&.source_url || "#{DataSources.config.dig('sofiaplan', 'base_url')}/datasets/#{config.fetch('id')}",
            error: StandardError.new("A reliable property location is required before this dataset can be applied")
          )
        elsif dataset&.last_imported_at
          DataSources::Result.success(
            data: { "category" => key, "feature_count" => dataset.spatial_features.count },
            source_url: dataset.source_url, fetched_at: dataset.last_imported_at, relevant_at: dataset.relevant_at
          )
        elsif @spatial_sync_results&.key?(key)
          @spatial_sync_results.fetch(key)
        else
          DataSources::Result.unavailable(
            source_url: "#{DataSources.config.dig("sofiaplan", "base_url")}/datasets/#{config.fetch("id")}",
            error: StandardError.new("Configured dataset has not been imported")
          )
        end
        record_result("sofiaplan_dataset_#{key}", result)
      end
    end

    def import_missing_spatial_datasets
      missing_keys = DataSources.config.dig("sofiaplan", "datasets").keys.reject do |key|
        SpatialDataset.where(key:).where.not(last_imported_at: nil).exists?
      end
      return if missing_keys.empty?

      synchronizer = DataSources::Sofiaplan::DatasetSynchronizer.new
      @spatial_sync_results = missing_keys.each_with_object({}) do |key, results|
        results.merge!(synchronizer.sync(key))
      end
    end

    def persist_act(record)
      attributes = record.slice(
        "act_number", "title", "status", "issued_on", "effective_on", "issuer", "district", "locality",
        "upi", "address", "object_description", "construction_category", "built_up_area", "gross_floor_area",
        "source_url", "document_url", "properties"
      )
      attributes["geometry"] = point_from(record)
      act = AdministrativeAct.find_or_initialize_by(
        registry_kind: record.fetch("registry_kind"), external_key: record.fetch("external_key")
      )
      act.assign_attributes(attributes)
      act.save!
      identifiers = Array(record["cadastral_identifiers"])
      identifiers << record["matched_identifier"] if record["matched_identifier"].present?
      identifiers.uniq.each do |identifier|
        parsed = CadastralIdentifier.new(identifier)
        next unless parsed.valid?

        act.administrative_act_references.find_or_create_by!(cadastral_identifier: parsed.to_s) do |reference|
          reference.reference_level = parsed.level.to_s
        end
      end
    end

    def point_from(record)
      return unless record["longitude"] && record["latitude"]

      RGeo::Geographic.spherical_factory(srid: 4326).point(record["longitude"].to_f, record["latitude"].to_f)
    end

    def record_result(source_key, result, request_metadata: {})
      payload = serializable_payload(result.data)
      @analysis.source_runs.create!(
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

    def set_stage(key, status)
      @current_stage = key
      @analysis.update_progress!(key, status)
    end

    def current_stage = @current_stage
    def cadastre_district_hint
      @nag_records.lazy.map do |record|
        record["district"].presence || record.dig("properties", "RegionName").presence
      end.find(&:present?)
    end
    def nag_config = DataSources.config.dig("nag", "registers")
    def arcgis_config = DataSources.config.fetch("arcgis")
  end
end
