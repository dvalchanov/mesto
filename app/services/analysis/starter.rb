module Analysis
  class Starter
    REUSE_WINDOW = 24.hours

    def initialize(identifier)
      @identifier = identifier
    end

    def call
      reusable || create
    end

    private

    def reusable
      PropertyAnalysis.completed.where(submitted_identifier: @identifier.to_s)
        .where(completed_at: REUSE_WINDOW.ago..).order(completed_at: :desc).first
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
  end
end
