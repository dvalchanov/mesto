module Analysis
  class SharedSpatialCalculationCache
    VERSION = 1

    def initialize(analysis:, calculation_kind:, subject_key:, geometry:, geometry_basis:)
      @analysis = analysis
      @calculation_kind = calculation_kind
      @subject_key = subject_key
      @geometry = geometry
      @geometry_basis = geometry_basis
    end

    def fetch
      cached = SharedSpatialCalculation.find_by(fingerprint:)
      return cached.result.deep_dup if cached

      result = yield
      SharedSpatialCalculation.create!(
        subject_key: @subject_key,
        calculation_kind: @calculation_kind,
        fingerprint:,
        geometry_basis: @geometry_basis,
        coverage_profile_key: @analysis.coverage_profile_key || DataCoverage.profile.key,
        dataset_revisions:,
        result:,
        calculated_at: Time.current
      )
      result
    rescue ActiveRecord::RecordNotUnique
      SharedSpatialCalculation.find_by!(fingerprint:).result.deep_dup
    end

    private

    def fingerprint
      @fingerprint ||= Digest::SHA256.hexdigest(JSON.generate([
        VERSION,
        @calculation_kind,
        @subject_key,
        @geometry_basis,
        @geometry&.as_text,
        @analysis.coverage_profile_key,
        dataset_revisions,
        source_state
      ]))
    end

    def dataset_revisions
      @dataset_revisions ||= SpatialDataset.prepared
        .where(coverage_profile_key: @analysis.coverage_profile_key)
        .to_h { |dataset| [ dataset.key, [ dataset.importer_version, dataset.revision_key ] ] }
    end


    def source_state
      @analysis.current_source_runs.order(:source_key, :id).pluck(:source_key, :status)
    end
  end
end
