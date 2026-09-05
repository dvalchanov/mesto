module Education
  class BuildingMilestoneResolver
    Assessment = Data.define(
      :milestone, :evidence_basis, :evidence_record_ids, :evidence_date,
      :source_checked_at, :subject_scope, :match_quality, :limitations,
      :conflict_flags, :inference_rule_version
    )

    RULE_VERSION = 1
    MILESTONES = {
      "building_permits" => "authorization",
      "occupancy_certificates" => "commissioning"
    }.freeze
    ORDER = BuyerJourney::BUILDING_STAGES.index_with.with_index.to_h.freeze

    def initialize(analysis:, reported_stage: nil, visible_acts: nil)
      @analysis = analysis
      @reported_stage = reported_stage
      @adapter = ReportEvidenceAdapter.new(analysis:, visible_acts:)
    end

    def call
      supported, mismatched, disputed = classified_candidates
      best = supported.max_by { |act| [ ORDER.fetch(MILESTONES.fetch(act.registry_kind), -1), act.issued_on || Date.new(1900) ] }
      milestone = best && MILESTONES[best.registry_kind]
      limitations = []
      limitations << "Няма намерен съвпадащ документ в проверените източници; това не доказва, че такъв не съществува." unless best
      limitations << "Има запис за парцела или друг обхват, който не е приложен към избраната сграда." if mismatched.any?
      limitations << "Има отменен, оспорен или неясен запис, който не е използван като доказателство." if disputed.any?

      Assessment.new(
        milestone:,
        evidence_basis: best ? "direct_official_record" : "unavailable",
        evidence_record_ids: best ? [ best.id ] : [],
        evidence_date: best&.issued_on,
        source_checked_at: @adapter.source_checked_at,
        subject_scope: best ? matched_scope(best) : "unresolved",
        match_quality: best ? "exact_subject" : mismatched.any? ? "wrong_or_broad_subject" : "no_matching_record",
        limitations:,
        conflict_flags: conflict_flags(milestone, disputed),
        inference_rule_version: RULE_VERSION
      )
    end

    private

    def classified_candidates
      supported = []
      mismatched = []
      disputed = []
      @adapter.acts.select { |act| MILESTONES.key?(act.registry_kind) }.each do |act|
        if disputed?(act)
          disputed << act
        elsif directly_matches?(act)
          supported << act
        else
          mismatched << act
        end
      end
      [ supported, mismatched, disputed ]
    end

    def disputed?(act)
      [ act.status, act.title ].compact.join(" ").match?(/отмен|оспор|revok|annul|неяс/i)
    end

    def directly_matches?(act)
      return false if infrastructure_only?(act)

      references = evidence_references(act).map(&:cadastral_identifier)
      exact_targets = [ @analysis.individual_object_identifier, @analysis.building_identifier ].compact
      return true if (references & exact_targets).any?

      @analysis.identifier_level == "parcel" &&
        act.registry_kind == "building_permits" &&
        references.include?(@analysis.parcel_identifier)
    end

    def infrastructure_only?(act)
      return false unless act.registry_kind == "occupancy_certificates"

      [ act.title, act.object_description ].compact.join(" ").match?(/трафопост|електропровод|външн.{0,12}(връз|захран)|канализац|водопровод|улица|път|инфраструктур/i)
    end

    def matched_scope(act)
      references = evidence_references(act).map(&:cadastral_identifier)
      return "individual_object" if @analysis.individual_object_identifier && references.include?(@analysis.individual_object_identifier)
      return "building" if @analysis.building_identifier && references.include?(@analysis.building_identifier)
      return "parcel" if references.include?(@analysis.parcel_identifier)

      "unresolved"
    end

    def evidence_references(act)
      act.administrative_act_references.select { |reference| reference.match_basis == "document" }
    end

    def conflict_flags(milestone, disputed)
      flags = []
      flags << "disputed_record" if disputed.any?
      if milestone && @reported_stage.present? && @reported_stage != "unknown"
        flags << "later_evidence_than_reported" if ORDER.fetch(milestone, -1) > ORDER.fetch(@reported_stage, -1)
      end
      flags
    end
  end
end
