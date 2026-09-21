module PropertyFinder
  class BuildingMap
    MAX_FEATURES = 300

    Result = Data.define(:geojson, :count, :truncated, :center)

    def initialize(query: nil, bbox: nil, initial: false)
      @query = query.to_s.squish.first(PropertyFinder::AddressSearch::MAX_QUERY_LENGTH)
      @bbox = parse_bbox(bbox)
      @initial = ActiveModel::Type::Boolean.new.cast(initial)
    end

    def call
      if @initial && @query.blank? && @bbox.nil?
        return Result.new(
          geojson: empty_feature_collection,
          count: 0,
          truncated: false,
          center: initial_center
        )
      end

      records = matching_scope.order(:cadastral_identifier).limit(MAX_FEATURES + 1).to_a
      truncated = records.length > MAX_FEATURES
      records = records.first(MAX_FEATURES)

      Result.new(
        geojson: {
          type: "FeatureCollection",
          features: records.map { |record| feature(record) }
        },
        count: records.length,
        truncated:,
        center: nil
      )
    end

    private

    def matching_scope
      scope = building_scope
      if @query.present?
        search = PropertyFinder::BuildingSearch.new(query: @query, limit: MAX_FEATURES)
        @matching_addresses = search.matching_addresses
        scope.where(cadastral_identifier: search.matching_building_identifiers)
      elsif @bbox
        scope.where(
          "geometry && ST_MakeEnvelope(?, ?, ?, ?, 4326)",
          @bbox[0], @bbox[1], @bbox[2], @bbox[3]
        )
      else
        scope.none
      end
    end

    def building_scope
      CadastralProperty.usable
        .where(identifier_level: "building")
        .where("objects_count > 0")
        .where.not(geometry: nil)
    end

    def empty_feature_collection
      { type: "FeatureCollection", features: [] }
    end

    def initial_center
      longitude, latitude = building_scope.pick(
        Arel.sql("percentile_cont(0.5) WITHIN GROUP (ORDER BY ST_X(ST_PointOnSurface(geometry)))"),
        Arel.sql("percentile_cont(0.5) WITHIN GROUP (ORDER BY ST_Y(ST_PointOnSurface(geometry)))")
      )
      return unless longitude && latitude

      nearest = building_scope
        .order(Arel.sql(CadastralProperty.sanitize_sql_array([
          "geometry <-> ST_SetSRID(ST_MakePoint(?, ?), 4326)", longitude, latitude
        ])))
        .pick(
          Arel.sql("ST_X(ST_PointOnSurface(geometry))"),
          Arel.sql("ST_Y(ST_PointOnSurface(geometry))")
        )
      nearest&.map(&:to_f)
    end

    def parse_bbox(value)
      coordinates = value.to_s.split(",", 4).map { |part| Float(part, exception: false) }
      return unless coordinates.length == 4 && coordinates.all?

      west, south, east, north = coordinates
      return unless west.between?(-180, 180) && east.between?(-180, 180)
      return unless south.between?(-90, 90) && north.between?(-90, 90)
      return unless west < east && south < north

      coordinates
    end

    def feature(record)
      {
        type: "Feature",
        id: record.cadastral_identifier,
        geometry: RGeo::GeoJSON.encode(record.geometry),
        properties: {
          identifier: record.cadastral_identifier,
          address: @matching_addresses&.fetch(record.cadastral_identifier, nil) || record.address,
          objects_count: record.objects_count
        }.compact
      }
    end
  end
end
