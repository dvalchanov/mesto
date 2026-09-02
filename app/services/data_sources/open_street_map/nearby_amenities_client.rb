module DataSources
  module OpenStreetMap
    class NearbyAmenitiesClient
      RADIUS_METRES = 2_000
      QUERY_TIMEOUT_SECONDS = 8
      EARTH_RADIUS_METRES = 6_371_008.8
      CATEGORY_BY_AMENITY = {
        "school" => "schools",
        "kindergarten" => "kindergartens"
      }.freeze

      def initialize(config: DataSources.config.fetch("openstreetmap"), http_client: nil)
        @endpoint = config.fetch("overpass_url")
        @http_client = http_client || HttpClient.new(open_timeout: 4, read_timeout: 12, retries: 0)
      end

      def fetch(centroid:)
        body = if DataSources.fixture?
          FixtureLoader.read("openstreetmap_nearby_amenities.json")
        else
          @http_client.get(@endpoint, data: query(centroid)).body
        end
        payload = JSON.parse(body)
        relevant_at = parse_timestamp(payload.dig("osm3s", "timestamp_osm_base"))
        data = {
          "provider" => "OpenStreetMap",
          "radius_m" => RADIUS_METRES,
          "features" => normalize_features(payload.fetch("elements", []), centroid),
          "license_url" => "https://www.openstreetmap.org/copyright"
        }
        data["relevant_at"] = relevant_at.iso8601 if relevant_at
        Result.success(data:, source_url: @endpoint, relevant_at:, raw_response: body)
      rescue JSON::ParserError, KeyError => error
        Result.failure(source_url: @endpoint, error:)
      rescue StandardError => error
        Result.unavailable(source_url: @endpoint, error:)
      end

      private

      def query(centroid)
        latitude = format("%.7f", centroid.y)
        longitude = format("%.7f", centroid.x)
        <<~OVERPASS.squish
          [out:json][timeout:#{QUERY_TIMEOUT_SECONDS}][maxsize:2097152];
          nw["amenity"~"^(school|kindergarten)$"](around:#{RADIUS_METRES},#{latitude},#{longitude});
          out center tags qt;
        OVERPASS
      end

      def normalize_features(elements, centroid)
        elements.filter_map do |element|
          tags = element.fetch("tags", {})
          category = CATEGORY_BY_AMENITY[tags["amenity"]]
          coordinates = coordinates_for(element)
          next unless category && coordinates

          distance = distance_metres(centroid.y, centroid.x, coordinates.fetch(:latitude), coordinates.fetch(:longitude))
          next if distance > RADIUS_METRES

          {
            "category" => category,
            "name" => tags["name:bg"].presence || tags["name"].presence || tags["official_name"].presence,
            "address" => address(tags),
            "operator" => tags["operator"].presence,
            "latitude" => coordinates.fetch(:latitude),
            "longitude" => coordinates.fetch(:longitude),
            "distance_m" => distance.round,
            "source_url" => "https://www.openstreetmap.org/#{element.fetch('type')}/#{element.fetch('id')}"
          }.compact
        end.sort_by { |feature| feature.fetch("distance_m") }
      end

      def coordinates_for(element)
        latitude = element["lat"] || element.dig("center", "lat")
        longitude = element["lon"] || element.dig("center", "lon")
        { latitude: latitude.to_f, longitude: longitude.to_f } if latitude && longitude
      end

      def address(tags)
        return tags["addr:full"] if tags["addr:full"].present?

        [ tags["addr:street"], tags["addr:housenumber"] ].compact_blank.join(" ").presence
      end

      def distance_metres(from_latitude, from_longitude, to_latitude, to_longitude)
        latitude_delta = radians(to_latitude - from_latitude)
        longitude_delta = radians(to_longitude - from_longitude)
        from_latitude = radians(from_latitude)
        to_latitude = radians(to_latitude)
        haversine = Math.sin(latitude_delta / 2)**2 +
          Math.cos(from_latitude) * Math.cos(to_latitude) * Math.sin(longitude_delta / 2)**2
        EARTH_RADIUS_METRES * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine))
      end

      def radians(value)
        value * Math::PI / 180
      end

      def parse_timestamp(value)
        Time.iso8601(value) if value.present?
      rescue ArgumentError
        nil
      end
    end
  end
end
