module PropertyFinder
  class BuildingSearch
    MAX_RESULTS = 8
    MAX_MATCHING_BUILDINGS = 300
    BUILDING_IDENTIFIER_SQL = PropertyFinder::AddressSearch::BUILDING_IDENTIFIER_SQL

    Suggestion = Data.define(:address, :building_count, :building_identifier)
    Candidate = Data.define(:identifier, :address, :street_name, :street_number)

    attr_reader :query

    def initialize(query:, limit: MAX_RESULTS)
      @query = query.to_s.squish.first(PropertyFinder::AddressSearch::MAX_QUERY_LENGTH)
      @limit = limit.to_i.clamp(1, 50)
    end

    def call
      grouped_candidates.first(@limit).map do |candidates|
        identifiers = candidates.map(&:identifier).uniq
        display_candidate = candidates.max_by { |candidate| address_score(candidate) }
        Suggestion.new(
          address: display_candidate.address,
          building_count: identifiers.length,
          building_identifier: identifiers.one? ? identifiers.first : nil
        )
      end
    end

    def matching_scope
      identifiers = matching_building_identifiers
      return CadastralProperty.usable.none if identifiers.empty?

      CadastralProperty.usable.where(
        identifier_level: "building",
        cadastral_identifier: identifiers
      ).where.not(geometry: nil)
    end

    def matching_building_identifiers
      candidates_by_identifier.keys
    end

    def matching_addresses
      candidates_by_identifier.transform_values(&:address)
    end

    private

    def grouped_candidates
      candidates_by_identifier.values
        .group_by { |candidate| address_key(candidate) }
        .values
        .sort_by { |candidates| suggestion_rank(candidates) }
    end

    def candidates_by_identifier
      @candidates_by_identifier ||= begin
        candidates = {}
        matching_building_records.each do |record|
          merge_candidate(candidates, candidate_from_building(record))
        end
        matching_unit_records.each do |record|
          merge_candidate(candidates, candidate_from_unit(record))
        end
        candidates
      end
    end

    def matching_building_records
      AddressQuery.new(query).apply(
        CadastralProperty.usable.where(identifier_level: "building").where.not(geometry: nil)
      ).order(:cadastral_identifier).limit(MAX_MATCHING_BUILDINGS + 1)
    end

    def matching_unit_records
      scope = AddressQuery.new(query).apply(
        CadastralProperty.usable.where(identifier_level: "individual_object")
      )
      scope
        .select(Arel.sql("DISTINCT ON (#{BUILDING_IDENTIFIER_SQL}) cadastral_properties.*"))
        .order(Arel.sql("#{BUILDING_IDENTIFIER_SQL}, char_length(address) DESC"))
        .limit(MAX_MATCHING_BUILDINGS + 1)
    end

    def candidate_from_building(record)
      Candidate.new(
        identifier: record.cadastral_identifier,
        address: record.address,
        street_name: record.street_name,
        street_number: record.street_number
      )
    end

    def candidate_from_unit(record)
      Candidate.new(
        identifier: record.cadastral_identifier.sub(/\.[^.]+\z/, ""),
        address: building_address(record.address),
        street_name: record.street_name,
        street_number: record.street_number
      )
    end

    def merge_candidate(candidates, candidate)
      existing = candidates[candidate.identifier]
      better_address = existing && (address_score(candidate) <=> address_score(existing)) == 1
      candidates[candidate.identifier] = candidate if existing.nil? || better_address
    end

    def address_score(candidate)
      [ candidate.street_name.present? ? 1 : 0, candidate.street_number.present? ? 1 : 0, candidate.address.to_s.length ]
    end

    def address_key(candidate)
      if candidate.street_name.present?
        "street:#{normalize(candidate.street_name)}:#{candidate.street_number}"
      else
        "address:#{normalize(candidate.address)}"
      end
    end

    def normalize(value)
      value.to_s.downcase.scan(/[[:alnum:]]+/).join(" ")
    end

    def suggestion_rank(candidates)
      display_candidate = candidates.max_by { |candidate| address_score(candidate) }
      normalized_address = normalize(display_candidate.address)
      term_positions = AddressQuery.new(query).terms.filter_map { |term| normalized_address.index(term) }
      [ term_positions.sum, candidates.map(&:identifier).uniq.length, normalized_address.length ]
    end

    def building_address(address)
      address.to_s.sub(/,\s*(?:вх\.?|ет\.?|ап\.?|ателие|гараж|склад|обект)\b.*\z/i, "")
    end
  end
end
