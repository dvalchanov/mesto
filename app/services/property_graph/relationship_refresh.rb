module PropertyGraph
  class RelationshipRefresh
    def initialize(analysis:, source_key:, refresh_scope:, observed_at: Time.current)
      @analysis = analysis
      @source_key = source_key
      @refresh_scope = refresh_scope
      @observed_at = observed_at
    end

    def call(claims)
      seen = []
      Relationship.transaction do
        Array(claims).each do |claim|
          relationship = persist_claim(claim.deep_symbolize_keys)
          seen << relationship.fingerprint if relationship.active?
        end
        close_missing_current_relationships(seen)
      end
    end

    private

    def persist_claim(claim)
      fingerprint = fingerprint_for(claim)
      relationship = Relationship.find_or_initialize_by(fingerprint:)
      relationship.assign_attributes(
        property_analysis: @analysis,
        source_run: claim[:source_run],
        subject_entity: claim.fetch(:subject_entity),
        object_entity: claim.fetch(:object_entity),
        relationship_type: claim.fetch(:relationship_type),
        status: claim.fetch(:status, "exact"),
        claim_origin: claim.fetch(:claim_origin, "public_source"),
        source_key: @source_key,
        source_url: claim.fetch(:source_url),
        source_record_reference: claim.fetch(:source_record_reference),
        source_date: claim[:source_date],
        first_observed_at: relationship.first_observed_at || @observed_at,
        last_observed_at: @observed_at,
        valid_from: claim[:valid_from],
        valid_until: claim[:valid_until],
        active: claim.fetch(:active, true),
        superseded_at: nil,
        subject_scope: PrivacyFilter.call(claim.fetch(:subject_scope).to_h),
        object_scope: PrivacyFilter.call(claim.fetch(:object_scope).to_h),
        evidence: PrivacyFilter.call(claim.fetch(:evidence, {}).to_h),
        coverage_limitation: claim[:coverage_limitation],
        refresh_scope: @refresh_scope
      )
      relationship.save!
      relationship
    end

    def close_missing_current_relationships(seen)
      scope = Relationship.current.where(
        property_analysis: @analysis,
        source_key: @source_key,
        refresh_scope: @refresh_scope
      )
      scope = scope.where.not(fingerprint: seen) if seen.any?
      scope.update_all(active: false, superseded_at: @observed_at, updated_at: @observed_at)
    end

    def fingerprint_for(claim)
      Digest::SHA256.hexdigest(JSON.generate([
        @analysis.id,
        claim.fetch(:subject_entity).canonical_key,
        claim.fetch(:object_entity).canonical_key,
        claim.fetch(:relationship_type),
        @source_key,
        claim.fetch(:source_record_reference),
        claim[:source_date]&.iso8601,
        claim[:valid_from]&.iso8601,
        claim[:valid_until]&.iso8601,
        claim.fetch(:status, "exact"),
        PrivacyFilter.call(claim.fetch(:evidence, {}).to_h),
        claim[:coverage_limitation],
        claim.fetch(:claim_origin, "public_source")
      ]))
    end
  end
end
