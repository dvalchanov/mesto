module DataCoverage
  class Profile
    CONFIG_PATH = Rails.root.join("config/coverage_profiles.yml")

    attr_reader :key, :label, :mode, :import_behavior, :supporting_buffer_metres, :districts

    def self.current
      new(config_for(Rails.env))
    end

    def self.find(key)
      environment, config = all.find { |_environment, candidate| candidate.fetch("key") == key.to_s }
      raise KeyError, "Unknown coverage profile: #{key}" unless config

      new(config.merge("environment" => environment))
    end

    def self.all
      YAML.safe_load(ERB.new(CONFIG_PATH.read).result, aliases: true)
    end

    def self.config_for(environment)
      all.fetch(environment.to_s).merge("environment" => environment.to_s)
    end

    def initialize(config)
      @config = config.deep_stringify_keys
      @key = @config.fetch("key")
      @label = @config.fetch("label")
      @mode = @config.fetch("mode")
      @import_behavior = @config.fetch("import_behavior")
      @supporting_buffer_metres = Integer(@config.fetch("supporting_buffer_metres"))
      required_buffer = Array(DataSources.config.fetch("analysis_radii_metres")).map(&:to_i).max
      if @supporting_buffer_metres < required_buffer
        raise ArgumentError, "Coverage buffer must include the largest configured analysis radius (#{required_buffer} m)"
      end
      @districts = Array(@config["districts"])
    end

    def search_geometry
      @search_geometry ||= parse(@config.fetch("search_polygon_wkt"))
    end

    def search_geometry_wkt
      search_geometry.as_text
    end

    def supporting_geometry_wkt
      @supporting_geometry_wkt ||= connection.select_value(sql_array([
        "SELECT ST_AsText(ST_Buffer(ST_GeomFromText(?, 4326)::geography, ?)::geometry)",
        search_geometry_wkt, supporting_buffer_metres
      ]))
    end

    def supporting_geometry
      @supporting_geometry ||= parse(supporting_geometry_wkt)
    end

    def scope_digest
      Digest::SHA256.hexdigest([ key, search_geometry_wkt, supporting_buffer_metres ].join(":"))
    end

    def covers_property?(property)
      return false unless property&.geometry
      return false unless intersects?(search_geometry_wkt, property.geometry.as_text)
      return true unless mode == "catalog"

      CadastreSourceArchive.where(
        source_archive_key: property.source_archive_key,
        coverage_profile_key: key,
        enabled: true
      ).exists?
    end

    def supports_geometry_wkt?(geometry_wkt, srid: 4326)
      return false if geometry_wkt.blank?

      sql = <<~SQL.squish
        SELECT ST_Intersects(
          ST_GeomFromText(?, 4326),
          ST_Transform(ST_MakeValid(ST_GeomFromText(?, ?)), 4326)
        )
      SQL
      connection.select_value(sql_array([
        sql, supporting_geometry_wkt, geometry_wkt, srid
      ]))
    rescue ActiveRecord::StatementInvalid
      false
    end

    def envelope
      value = connection.select_value(sql_array([
        "SELECT ST_Extent(ST_GeomFromText(?, 4326))::text", supporting_geometry_wkt
      ]))
      value.delete_prefix("BOX(").delete_suffix(")").split(",").flat_map { |point| point.split.map(&:to_f) }
    end

    def bounding_box
      row = connection.select_one(sql_array([ <<~SQL.squish, supporting_geometry_wkt ]))
        SELECT ST_XMin(Box3D(geometry)) AS west,
          ST_YMin(Box3D(geometry)) AS south,
          ST_XMax(Box3D(geometry)) AS east,
          ST_YMax(Box3D(geometry)) AS north
        FROM (SELECT ST_GeomFromText(?, 4326) AS geometry) boundaries
      SQL
      row.symbolize_keys.transform_values(&:to_f)
    end

    private

    def parse(wkt)
      RGeo::WKRep::WKTParser.new(
        RGeo::Geographic.spherical_factory(srid: 4326), support_ewkt: true
      ).parse(wkt)
    end

    def intersects?(left_wkt, right_wkt)
      connection.select_value(sql_array([
        "SELECT ST_Intersects(ST_GeomFromText(?, 4326), ST_GeomFromText(?, 4326))",
        left_wkt, right_wkt
      ]))
    end

    def connection
      ActiveRecord::Base.connection
    end

    def sql_array(value)
      ApplicationRecord.send(:sanitize_sql_array, value)
    end
  end
end
