module PropertyGraph
  class ObservationWriter
    def self.call(...) = new.call(...)

    def call(entity:, analysis:, source_key:, source_url:, source_record_reference:, observed_at: Time.current,
      source_date: nil, source_run: nil, attributes: {}, evidence: {}, coverage_limitation: nil,
      claim_origin: "public_source")
      safe_attributes = PrivacyFilter.call(attributes.to_h)
      safe_evidence = PrivacyFilter.call(evidence.to_h)
      fingerprint = Digest::SHA256.hexdigest(JSON.generate([
        entity.canonical_key, analysis.id, source_key, source_record_reference,
        source_date&.iso8601, safe_attributes, safe_evidence, coverage_limitation, claim_origin
      ]))

      observation = EntityObservation.find_or_initialize_by(fingerprint:)
      observation.assign_attributes(
        property_graph_entity: entity,
        property_analysis: analysis,
        source_run:,
        source_key:,
        source_url:,
        source_record_reference:,
        source_date:,
        observed_at:,
        facts: safe_attributes,
        evidence: safe_evidence,
        coverage_limitation:,
        claim_origin:
      )
      observation.save!
      observation
    end
  end
end
