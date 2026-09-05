module Education
  class ReportEvidenceAdapter
    DOCUMENT_KEYS = {
      "building_permits" => "document.building_permit",
      "design_visas" => "document.design_visa",
      "urban_planning_orders" => "document.pup",
      "occupancy_certificates" => "document.commissioning"
    }.freeze

    def self.document_key_for(act)
      DOCUMENT_KEYS[act.registry_kind]
    end

    def initialize(analysis:, visible_acts: nil)
      @analysis = analysis
      @visible_acts = visible_acts || analysis.administrative_acts.includes(:administrative_act_references)
    end

    def acts
      Array(@visible_acts)
    end

    def source_checked_at
      runs = @analysis.source_runs.where("source_key LIKE ?", "nag_%")
      runs.maximum(:fetched_at) || runs.maximum(:created_at)
    end

    def source_coverage
      runs = @analysis.source_runs.where("source_key LIKE ?", "nag_%")
      return "unavailable" if runs.empty? || runs.where(status: "succeeded").none?
      return "partial" if runs.where(status: %w[failed unavailable]).exists?

      "available"
    end
  end
end
