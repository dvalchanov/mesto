module PropertyFinder
  class AddressSearch
    PAGE_SIZE = 24
    MAX_BUILDINGS = 8
    MAX_QUERY_LENGTH = 120
    BUILDING_IDENTIFIER_SQL = "regexp_replace(cadastral_identifier, '\\.[^.]+$', '')".freeze
    Result = Data.define(
      :query, :properties, :total_count, :building_count, :building_identifiers, :building_addresses,
      :entrances, :floors, :page, :page_count, :filters, :buildings_truncated
    )

    def initialize(query:, filters: {}, page: 1, building_identifier: nil)
      @query = query.to_s.squish.first(MAX_QUERY_LENGTH)
      @filters = filters.to_h.stringify_keys.slice("entrance", "floor", "object_number", "area")
      @page = [ page.to_i, 1 ].max
      @building_identifier = normalized_building_identifier(building_identifier)
    end

    def call
      building_identifiers, buildings_truncated = matching_building_identifiers
      base_scope = scope_for_buildings(building_identifiers)
      filtered_scope = apply_filters(base_scope)
      total_count = filtered_scope.count
      page_count = [ (total_count.to_f / PAGE_SIZE).ceil, 1 ].max
      current_page = [ @page, page_count ].min

      Result.new(
        query: @query,
        properties: ordered(filtered_scope).offset((current_page - 1) * PAGE_SIZE).limit(PAGE_SIZE).to_a,
        total_count:,
        building_count: building_identifiers.length,
        building_identifiers:,
        building_addresses: building_addresses(building_identifiers),
        entrances: facet_values(base_scope, :entrance),
        floors: facet_values(base_scope, :floor),
        page: current_page,
        page_count:,
        filters: @filters,
        buildings_truncated:
      )
    end

    private

    def matching_building_identifiers
      if @building_identifier
        exists = individual_objects.where(
          "cadastral_identifier LIKE ?",
          "#{CadastralProperty.sanitize_sql_like(@building_identifier)}.%"
        ).exists?
        return [ exists ? [ @building_identifier ] : [], false ]
      end

      identifiers = matching_address_scope
        .distinct
        .limit(MAX_BUILDINGS + 1)
        .pluck(Arel.sql(BUILDING_IDENTIFIER_SQL))

      [ identifiers.first(MAX_BUILDINGS), identifiers.length > MAX_BUILDINGS ]
    end

    def matching_address_scope
      AddressQuery.new(@query).apply(individual_objects)
    end

    def individual_objects
      CadastralProperty.where(identifier_level: "individual_object")
    end

    def scope_for_buildings(identifiers)
      return residential_units.none if identifiers.empty?

      ranges = identifiers.map do |identifier|
        residential_units.where("cadastral_identifier LIKE ?", "#{CadastralProperty.sanitize_sql_like(identifier)}.%")
      end
      ranges.drop(1).reduce(ranges.first, &:or)
    end

    def residential_units
      coded = individual_objects.where(purpose_code: %w[500 521])
      described = individual_objects.where("lower(purpose) LIKE '%жилищ%' OR lower(purpose) LIKE '%апартамент%'")
      coded.or(described)
    end

    def apply_filters(scope)
      scope = scope.where(entrance: @filters["entrance"]) if @filters["entrance"].present?
      scope = scope.where(floor: @filters["floor"]) if @filters["floor"].present?
      if @filters["object_number"].present?
        number = CadastralProperty.sanitize_sql_like(@filters["object_number"].squish)
        scope = scope.where("lower(object_number) LIKE ?", "%#{number.downcase}%")
      end
      if (area = decimal_filter(@filters["area"]))
        scope = scope.where(area_sqm: (area - 5)..(area + 5))
      end
      scope
    end

    def decimal_filter(value)
      return if value.blank?

      BigDecimal(value.to_s.tr(",", "."))
    rescue ArgumentError
      nil
    end

    def ordered(scope)
      scope.order(
        Arel.sql("entrance ASC NULLS LAST"),
        Arel.sql("CASE WHEN floor ~ '^-?[0-9]+$' THEN floor::integer END ASC NULLS LAST"),
        Arel.sql("floor ASC NULLS LAST"),
        Arel.sql("object_number ASC NULLS LAST"),
        :cadastral_identifier
      )
    end

    def facet_values(scope, field)
      scope.where.not(field => [ nil, "" ]).distinct.pluck(field).sort_by do |value|
        [ Integer(value, exception: false) ? 0 : 1, Integer(value, exception: false) || value.to_s ]
      end
    end

    def building_addresses(identifiers)
      recorded_addresses = CadastralProperty.where(
        identifier_level: "building",
        cadastral_identifier: identifiers
      ).pluck(:cadastral_identifier, :address).to_h

      identifiers.to_h do |identifier|
        address = scope_for_buildings([ identifier ])
          .where.not(address: [ nil, "" ])
          .order(Arel.sql("char_length(address) DESC"))
          .pick(:address)
        alternatives = [ recorded_addresses[identifier].presence, building_address(address).presence ].compact
        [ identifier, alternatives.max_by(&:length) ]
      end
    end

    def building_address(address)
      address.to_s.sub(/,\s*(?:вх\.?|ет\.?|ап\.?|ателие|гараж|склад|обект)\b.*\z/i, "")
    end

    def normalized_building_identifier(value)
      identifier = CadastralIdentifier.new(value)
      identifier.building_identifier if identifier.level == :building
    end
  end
end
