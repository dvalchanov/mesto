module Vies
  class Importer
    LIMITATION = "vies_vat_status_only"

    def initialize(analysis:, payload:, source_url:, source_run: nil, observed_at: Time.current, relevant_at: nil)
      @analysis = analysis
      @payload = payload.to_h.deep_stringify_keys
      @source_url = source_url
      @source_run = source_run
      @observed_at = observed_at
      @relevant_at = relevant_at
    end

    def call
      eik = BulgarianEik.normalize(@payload["eik"] || @payload["vat_number"])
      raise ArgumentError, "VIES payload has no valid EIK" unless BulgarianEik.valid?(eik)

      existing = PropertyGraph::Entity.find_by(canonical_key: "eik:#{eik}")
      entity = PropertyGraph::EntityResolver.call(
        entity_type: "company",
        canonical_key: "eik:#{eik}",
        display_name: @payload["legal_name"].presence || existing&.display_name || "ЕИК #{eik}",
        identifiers: { "eik" => eik },
        observed_at: @observed_at
      )
      PropertyGraph::ObservationWriter.call(
        entity:,
        analysis: @analysis,
        source_key: "vies",
        source_url: @source_url,
        source_record_reference: "BG#{eik}:#{@payload['request_date'] || 'undated'}",
        source_date: @relevant_at,
        observed_at: @observed_at,
        source_run: @source_run,
        attributes: {
          "eik" => eik,
          "vat_number" => "BG#{eik}",
          "vat_registered" => @payload.fetch("vat_valid"),
          "vat_checked_on" => @payload["request_date"],
          "vies_legal_name" => @payload["legal_name"]
        }.compact,
        evidence: { "basis" => "official_vies_check_by_exact_eik" },
        coverage_limitation: LIMITATION
      )
      entity
    end
  end
end
