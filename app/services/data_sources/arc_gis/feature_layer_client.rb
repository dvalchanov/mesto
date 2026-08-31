module DataSources
  module ArcGis
    class FeatureLayerClient
      DEFAULT_PAGE_SIZE = 1_000

      def initialize(layer_url:, http_client: HttpClient.new)
        @layer_url = layer_url.delete_suffix("/")
        @http_client = http_client
      end

      def metadata
        body = if DataSources.fixture?
          FixtureLoader.read("arcgis_metadata.json")
        else
          @http_client.get(@layer_url, f: "json").body
        end
        Result.success(data: JSON.parse(body), source_url: @layer_url, raw_response: body)
      rescue JSON::ParserError => error
        Result.failure(source_url: @layer_url, error: error)
      rescue StandardError => error
        Result.unavailable(source_url: @layer_url, error: error)
      end

      def query(geometry:, geometry_type: nil, spatial_rel: "esriSpatialRelIntersects", distance: nil, units: "esriSRUnit_Meter")
        query_url = "#{@layer_url}/query"
        return fixture_result(query_url) if DataSources.fixture?

        page_size = metadata.success? ? metadata.data.fetch("maxRecordCount", DEFAULT_PAGE_SIZE) : DEFAULT_PAGE_SIZE
        features = []
        offset = 0
        loop do
          response = @http_client.get(query_url, query_params(
            geometry:, geometry_type:, spatial_rel:, distance:, units:, offset:, page_size:
          ))
          payload = JSON.parse(response.body)
          raise Faraday::ParsingError, payload["error"].to_json if payload["error"]

          page_features = payload.fetch("features", [])
          features.concat(page_features)
          exceeded = payload["exceededTransferLimit"]
          break if exceeded == false || (exceeded.nil? && page_features.length < page_size)

          offset += page_size
        end

        Result.success(
          data: { "type" => "FeatureCollection", "features" => features },
          source_url: query_url
        )
      rescue JSON::ParserError, Faraday::ParsingError => error
        Result.failure(source_url: query_url, error: error)
      rescue StandardError => error
        Result.unavailable(source_url: query_url, error: error)
      end

      private

      def fixture_result(query_url)
        body = FixtureLoader.read("arcgis_geojson.json")
        Result.success(data: JSON.parse(body), source_url: query_url, raw_response: body)
      rescue StandardError => error
        Result.failure(source_url: query_url, error: error)
      end

      def query_params(geometry:, geometry_type:, spatial_rel:, distance:, units:, offset:, page_size:)
        {
          where: "1=1",
          geometry: serialized_geometry(geometry),
          geometryType: geometry_type || inferred_geometry_type(geometry),
          inSR: 4326,
          spatialRel: spatial_rel,
          outFields: "*",
          returnGeometry: true,
          outSR: 4326,
          f: "geojson",
          resultOffset: offset,
          resultRecordCount: page_size,
          distance:,
          units:
        }.compact
      end

      def serialized_geometry(geometry)
        case geometry
        when Array then geometry.join(",")
        when RGeo::Feature::Point then JSON.generate(x: geometry.x, y: geometry.y, spatialReference: { wkid: 4326 })
        else
          geojson = RGeo::GeoJSON.encode(geometry).deep_stringify_keys
          rings = geojson.fetch("type") == "MultiPolygon" ? geojson.fetch("coordinates").flatten(1) : geojson.fetch("coordinates")
          JSON.generate(rings:, spatialReference: { wkid: 4326 })
        end
      end

      def inferred_geometry_type(geometry)
        return "esriGeometryEnvelope" if geometry.is_a?(Array)
        return "esriGeometryPoint" if RGeo::Feature::Point === geometry

        "esriGeometryPolygon"
      end
    end
  end
end
