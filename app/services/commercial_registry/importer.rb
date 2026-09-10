module CommercialRegistry
  class Importer
    DEFAULT_COVERAGE_LIMITATION = "commercial_record_limited_coverage"

    def initialize(analysis:, payload:, source_url:, observed_at: Time.current, source_run: nil, relevant_at: nil)
      @analysis = analysis
      raw_payload = payload.to_h.deep_stringify_keys
      @demo_data = ActiveModel::Type::Boolean.new.cast(raw_payload["demo_data"])
      @data = PayloadNormalizer.call(raw_payload)
      @source_url = source_url
      @observed_at = observed_at
      @source_run = source_run
      @relevant_at = relevant_at
    end

    def call
      company_data = @data.fetch("company")
      company = PropertyGraph::EntityResolver.call(
        entity_type: "company",
        canonical_key: "eik:#{company_data.fetch('eik')}",
        display_name: company_data.fetch("legal_name"),
        identifiers: { "eik" => company_data.fetch("eik") },
        observed_at: @observed_at
      )
      record_reference = company_data.fetch("source_record_reference")
      source_date = company_data["source_date"] || @relevant_at
      limitation = @demo_data ? "synthetic_demo_data" : company_data["coverage_limitation"] || DEFAULT_COVERAGE_LIMITATION
      attributes = company_data.except(
        "source_record_reference", "source_date", "coverage_limitation"
      )
      PropertyGraph::ObservationWriter.call(
        entity: company,
        analysis: @analysis,
        source_key: "commercial_register",
        source_url: @source_url,
        source_record_reference: record_reference,
        source_date:,
        observed_at: @observed_at,
        source_run: @source_run,
        attributes:,
        evidence: { "basis" => company_evidence_basis, "eik" => company_data.fetch("eik") },
        coverage_limitation: limitation,
        claim_origin:
      )

      claims = @data.fetch("relationships").map do |relationship|
        related = PropertyGraph::EntityResolver.call(
          entity_type: relationship.fetch("entity_type"),
          canonical_key: relationship.fetch("canonical_key"),
          display_name: relationship.fetch("display_name"),
          identifiers: relationship.fetch("identifiers"),
          observed_at: @observed_at
        )
        PropertyGraph::ObservationWriter.call(
          entity: related,
          analysis: @analysis,
          source_key: "commercial_register",
          source_url: @source_url,
          source_record_reference: relationship["source_record_reference"] || record_reference,
          source_date: relationship["source_date"] || source_date,
          observed_at: @observed_at,
          source_run: @source_run,
          attributes: relationship.fetch("identifiers"),
          evidence: { "basis" => relationship_evidence_basis },
          coverage_limitation: limitation,
          claim_origin:
        )
        {
          subject_entity: company,
          object_entity: related,
          relationship_type: relationship.fetch("relationship_type"),
          status: relationship.fetch("status"),
          source_run: @source_run,
          source_url: @source_url,
          source_record_reference: relationship["source_record_reference"] || record_reference,
          source_date: relationship["source_date"] || source_date,
          valid_from: relationship["valid_from"],
          valid_until: relationship["valid_until"],
          active: relationship.fetch("active"),
          subject_scope: { "company_eik" => company_data.fetch("eik") },
          object_scope: relationship.fetch("identifiers").merge("entity_type" => relationship.fetch("entity_type")),
          evidence: relationship.fetch("evidence").merge("basis" => relationship_evidence_basis),
          coverage_limitation: limitation,
          claim_origin:
        }
      end
      PropertyGraph::RelationshipRefresh.new(
        analysis: @analysis,
        source_key: "commercial_register",
        refresh_scope: "commercial_register:#{company_data.fetch('eik')}",
        observed_at: @observed_at
      ).call(claims)
      company
    end

    private

    def claim_origin = @demo_data ? "synthetic_demo" : "public_source"

    def company_evidence_basis
      @demo_data ? "synthetic_demo_company_record" : "official_company_record"
    end

    def relationship_evidence_basis
      @demo_data ? "synthetic_demo_company_relationship" : "official_company_relationship"
    end
  end
end
