module PropertyFinder
  class AddressQuery
    STOP_WORDS = %w[
      bg bulgaria bulgariya city grad gr rayon region sofia sofiya street str ul bul boulevard blvd
      bulgariya град гр район софия улица ул булевард бул жк ж.к квартал кв
    ].freeze

    attr_reader :query

    def initialize(query)
      @query = query.to_s.squish.first(PropertyFinder::AddressSearch::MAX_QUERY_LENGTH)
    end

    def apply(scope)
      return scope.none if terms.empty?

      relation = terms.reduce(scope.where.not(address: nil)) do |current_scope, term|
        current_scope.where("lower(address) LIKE ?", "%#{CadastralProperty.sanitize_sql_like(term)}%")
      end
      return relation unless street_number

      escaped_number = Regexp.escape(street_number)
      relation.where(
        "street_number = :number OR (street_number IS NULL AND address ~* :number_pattern)",
        number: street_number,
        number_pattern: "№\\s*#{escaped_number}(?:[^[:alnum:]]|$)"
      )
    end

    def terms
      @terms ||= query.downcase.scan(/[[:alnum:]]+/).reject do |term|
        term == street_number || STOP_WORDS.include?(term) || term.length < 2
      end.uniq
    end

    def street_number
      @street_number ||= query.downcase.scan(/[[:alnum:]]+/).reverse.find { |term| term.match?(/\A\d+\z/) }
    end
  end
end
