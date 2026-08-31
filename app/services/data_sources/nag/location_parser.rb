module DataSources
  module Nag
    class LocationParser
      def self.call(record)
        longitude = record["longitude"]
        latitude = record["latitude"]
        return { address: record["address"] } unless longitude && latitude
        return { address: record["address"] } unless longitude.to_f.between?(-180, 180) && latitude.to_f.between?(-90, 90)

        factory = RGeo::Geographic.spherical_factory(srid: 4326)
        {
          centroid: factory.point(longitude.to_f, latitude.to_f),
          precision: "official_record_geometry",
          address: record["address"]
        }
      end
    end
  end
end
