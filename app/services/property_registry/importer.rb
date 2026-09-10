module PropertyRegistry
  class Importer
    def initialize(analysis:, payload:, source_url:, observed_at: Time.current, source_run: nil, relevant_at: nil)
      @analysis = analysis
      @payload = payload.to_h.deep_stringify_keys
      @source_url = source_url
      @observed_at = observed_at
      @source_run = source_run
      @relevant_at = relevant_at
      @demo_data = ActiveModel::Type::Boolean.new.cast(@payload["demo_data"])
    end

    def call
      identifier = @payload.fetch("property_identifier")
      parsed_identifier = CadastralIdentifier.new(identifier)
      raise PublicRegistry::InvalidPayload, "A valid cadastral identifier is required" unless parsed_identifier.valid?

      property = PropertyGraph::EntityResolver.call(
        entity_type: entity_type_for(parsed_identifier),
        canonical_key: "cadastre:#{parsed_identifier}",
        display_name: parsed_identifier.to_s,
        identifiers: { "cadastral_identifier" => parsed_identifier.to_s },
        observed_at: @observed_at
      )
      coverage = @payload.fetch("coverage", {}).to_h.deep_stringify_keys
      limitation = @demo_data ? "synthetic_demo_data" : coverage["limitation"].to_s.presence || default_limitation(coverage)
      claims = Array(@payload["owners"]).map do |raw_owner|
        owner = normalize_owner(raw_owner, property_identifier: parsed_identifier.to_s)
        related = PropertyGraph::EntityResolver.call(**owner.slice(
          :entity_type, :canonical_key, :display_name, :identifiers
        ), observed_at: @observed_at)
        PropertyGraph::ObservationWriter.call(
          entity: related,
          analysis: @analysis,
          source_key: "property_register",
          source_url: @source_url,
          source_record_reference: owner.fetch(:source_record_reference),
          source_date: owner[:source_date] || @relevant_at,
          observed_at: @observed_at,
          source_run: @source_run,
          attributes: owner.fetch(:identifiers),
          evidence: { "basis" => evidence_basis },
          coverage_limitation: limitation,
          claim_origin:
        )
        current = owner.fetch(:current)
        {
          subject_entity: property,
          object_entity: related,
          relationship_type: current ? "registered_owner" : "previous_registered_owner",
          status: "exact",
          source_run: @source_run,
          source_url: @source_url,
          source_record_reference: owner.fetch(:source_record_reference),
          source_date: owner[:source_date] || @relevant_at,
          valid_from: owner[:valid_from],
          valid_until: owner[:valid_until],
          active: current,
          subject_scope: { "cadastral_identifier" => parsed_identifier.to_s },
          object_scope: owner.fetch(:identifiers).merge("entity_type" => owner.fetch(:entity_type)),
          evidence: { "basis" => evidence_basis },
          coverage_limitation: limitation,
          claim_origin:
        }
      end
      PropertyGraph::RelationshipRefresh.new(
        analysis: @analysis,
        source_key: "property_register",
        refresh_scope: "property_register:#{parsed_identifier}",
        observed_at: @observed_at
      ).call(claims)
      property
    end

    private

    def claim_origin = @demo_data ? "synthetic_demo" : "public_source"

    def evidence_basis
      @demo_data ? "synthetic_demo_property_reference" : "registered_owner_in_supplied_property_reference"
    end

    def normalize_owner(raw_owner, property_identifier:)
      owner = raw_owner.to_h.deep_stringify_keys
      name = owner["legal_name"].presence || owner["name"].presence
      raise PublicRegistry::InvalidPayload, "Every owner requires a public display name" if name.blank?

      eik = BulgarianEik.normalize(owner["eik"])
      company = eik.present? && BulgarianEik.valid?(eik)
      entity_type = company ? "company" : "person"
      record_reference = owner["source_record_reference"].to_s.presence
      raise PublicRegistry::InvalidPayload, "Every owner requires a source record reference" unless record_reference

      current = owner.key?("current") ? ActiveModel::Type::Boolean.new.cast(owner["current"]) : owner["valid_until"].blank?
      canonical_key = if company
        "eik:#{eik}"
      else
        supplied_key = owner["identity_key"].to_s.presence
        scope = supplied_key || [ property_identifier, record_reference, name.downcase.gsub(/\s+/, " ") ].join(":")
        "property_register:person:#{Digest::SHA256.hexdigest(scope)[0, 32]}"
      end
      {
        entity_type:,
        canonical_key:,
        display_name: name,
        identifiers: company ? { "eik" => eik } : {},
        source_record_reference: record_reference,
        source_date: parse_time(owner["source_date"]),
        valid_from: parse_date(owner["valid_from"]),
        valid_until: parse_date(owner["valid_until"]),
        current:
      }
    end

    def entity_type_for(identifier)
      { parcel: "parcel", building: "building", individual_object: "property" }.fetch(identifier.level)
    end

    def default_limitation(coverage)
      return "property_history_incomplete" if coverage["complete_history"] == false

      "property_coverage_as_reported"
    end

    def parse_date(value)
      return value if value.is_a?(Date)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end

    def parse_time(value)
      return value if value.respond_to?(:iso8601) && !value.is_a?(String)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
