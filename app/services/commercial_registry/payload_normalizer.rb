module CommercialRegistry
  class PayloadNormalizer
    RELATIONSHIP_FIELDS = {
      "managers" => "managed_by",
      "owners" => "owned_by",
      "beneficial_owners" => "beneficially_owned_by"
    }.freeze
    COMPANY_FIELDS = %w[
      legal_name eik status registration_date legal_form liquidation_status insolvency_status
    ].freeze
    RELATIONSHIP_EVIDENCE_FIELDS = %w[
      representation ownership_percentage capacity share_class control_basis
    ].freeze

    def self.call(payload) = new(payload).call

    def initialize(payload)
      @payload = payload.to_h.deep_stringify_keys
    end

    def call
      raw_company = @payload.fetch("company", @payload)
      eik = BulgarianEik.normalize(raw_company["eik"])
      raise PublicRegistry::InvalidPayload, "A valid company EIK is required" unless BulgarianEik.valid?(eik)

      company = raw_company.slice(*COMPANY_FIELDS).compact_blank
      company["eik"] = eik
      company["legal_name"] = company["legal_name"].to_s.strip
      raise PublicRegistry::InvalidPayload, "A company legal name is required" if company["legal_name"].blank?

      company["registration_date"] = normalize_date(company["registration_date"])&.iso8601
      company["material_circumstances"] = normalize_circumstances(
        raw_company["material_circumstances"] || @payload["material_circumstances"]
      )
      company["coverage_limitation"] = raw_company["coverage_limitation"].to_s.presence
      company["source_record_reference"] = raw_company["source_record_reference"].to_s.presence || "company/#{eik}"
      company["source_date"] = normalize_time(raw_company["source_date"] || @payload["source_date"])

      relationships = RELATIONSHIP_FIELDS.flat_map do |field, relationship_type|
        Array(@payload[field] || raw_company[field]).filter_map do |entry|
          normalize_relationship(entry, relationship_type:, company_eik: eik)
        end
      end
      relationships.concat(Array(@payload["historical_relationships"]).filter_map do |entry|
        relationship_type = entry.to_h.stringify_keys["relationship_type"]
        next unless RELATIONSHIP_FIELDS.value?(relationship_type)

        normalize_relationship(entry, relationship_type:, company_eik: eik, historical: true)
      end)

      { "company" => company.compact, "relationships" => relationships }
    end

    private

    def normalize_relationship(raw_entry, relationship_type:, company_eik:, historical: false)
      entry = raw_entry.to_h.deep_stringify_keys
      name = (entry["legal_name"] || entry["name"]).to_s.strip
      return if name.blank?

      owner_eik = BulgarianEik.normalize(entry["eik"])
      entity_type = owner_eik.present? && BulgarianEik.valid?(owner_eik) ? "company" : "person"
      canonical_key = if entity_type == "company"
        "eik:#{owner_eik}"
      else
        stable_person_key(company_eik, relationship_type, name, entry["identity_key"])
      end
      valid_until = normalize_date(entry["valid_until"])
      active = if historical
        false
      elsif entry.key?("current")
        ActiveModel::Type::Boolean.new.cast(entry["current"])
      else
        valid_until.nil?
      end

      {
        "relationship_type" => relationship_type,
        "entity_type" => entity_type,
        "canonical_key" => canonical_key,
        "display_name" => name,
        "identifiers" => entity_type == "company" ? { "eik" => owner_eik } : {},
        "valid_from" => normalize_date(entry["valid_from"]),
        "valid_until" => valid_until,
        "active" => active,
        "status" => PropertyGraph::Relationship::STATUSES.include?(entry["status"]) ? entry["status"] : "exact",
        "source_record_reference" => entry["source_record_reference"].to_s.presence,
        "source_date" => normalize_time(entry["source_date"]),
        "evidence" => entry.slice(*RELATIONSHIP_EVIDENCE_FIELDS).compact_blank
      }
    end

    def stable_person_key(company_eik, relationship_type, name, supplied_key)
      scope = supplied_key.to_s.presence || [ company_eik, relationship_type, name.downcase.gsub(/\s+/, " ") ].join(":")
      "commercial_register:person:#{Digest::SHA256.hexdigest(scope)[0, 32]}"
    end

    def normalize_circumstances(value)
      Array(value).filter_map do |entry|
        attributes = entry.to_h.deep_stringify_keys.slice("type", "status", "date", "description").compact_blank
        attributes["date"] = normalize_date(attributes["date"])&.iso8601 if attributes["date"]
        attributes.presence
      end
    end

    def normalize_date(value)
      return value if value.is_a?(Date)
      return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end

    def normalize_time(value)
      return value if value.respond_to?(:iso8601) && !value.is_a?(String)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
