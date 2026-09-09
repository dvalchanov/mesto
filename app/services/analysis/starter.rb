module Analysis
  class Starter
    def initialize(identifier)
      @identifier = identifier
    end

    def call
      reusable || create
    end

    private

    def reusable
      candidates = PropertyAnalysis.completed.where(submitted_identifier: @identifier.to_s)
        .order(completed_at: :desc)
      candidates.find { |analysis| current_revision?(analysis) }
    end

    def create
      PropertyAnalysis.create!(
        submitted_identifier: @identifier.to_s,
        settlement_code: @identifier.settlement_code,
        parcel_identifier: @identifier.parcel_identifier,
        building_identifier: @identifier.building_identifier,
        individual_object_identifier: @identifier.individual_object_identifier,
        identifier_level: @identifier.level.to_s,
        status: "queued"
      ).tap { |analysis| AnalyzePropertyJob.perform_later(analysis.id) }
    end

    def current_revision?(analysis)
      revision = analysis.current_revision
      return false unless revision&.coverage_profile_key == DataCoverage.profile.key

      expected = PreparedDataRevisionSet.call(
        profile: DataCoverage.profile,
        identifiers: analysis.identifiers_for_matching
      )
      revision.dataset_revisions == expected
    end
  end
end
