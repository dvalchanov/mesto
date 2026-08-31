module DataSources
  module CadastreOpenData
    class PropertyArchiveImporter
      BATCH_SIZE = 500
      IMPORTER_VERSION = 2
      SOURCE_CRS = "EPSG:7801 (BGS2005 / CCS2005)".freeze
      ARCHIVE_LEVELS = {
        individual_objects: "individual_object",
        buildings: "building",
        parcels: "parcel"
      }.freeze

      def initialize(archive_path:, source_archive_key:, source_url:, archive_kind:, relevant_at: nil)
        @archive_path = Pathname(archive_path)
        @source_archive_key = source_archive_key
        @source_url = source_url
        @archive_kind = archive_kind.to_sym
        @identifier_level = ARCHIVE_LEVELS.fetch(@archive_kind)
        @relevant_at = relevant_at
      end

      def call
        file_checksum = Digest::SHA256.file(@archive_path).hexdigest
        checksum = Digest::SHA256.hexdigest("#{IMPORTER_VERSION}:#{file_checksum}")
        previous = CadastreImport.find_by(
          source_archive_key: @source_archive_key, checksum:, status: "succeeded",
          importer_version: IMPORTER_VERSION
        )
        return previous if previous

        import = CadastreImport.find_or_initialize_by(source_archive_key: @source_archive_key, checksum:)
        import.assign_attributes(
          source_archive_key: @source_archive_key, source_url: @source_url,
          importer_version: IMPORTER_VERSION,
          status: "running", started_at: Time.current, completed_at: nil,
          records_seen: 0, records_imported: 0, error_message: nil
        )
        import.save!
        import_archive(import)
        import
      rescue StandardError => error
        import&.update!(status: "failed", completed_at: Time.current, error_message: error.message.truncate(500))
        raise
      end

      private

      def import_archive(import)
        identifiers = []
        batch = []
        geometry_batch = []
        relevant_at = @relevant_at

        Zip::File.open(@archive_path) do |archive|
          dbf_entry = archive.entries.find { |candidate| candidate.name.downcase.end_with?(".dbf") }
          raise ArgumentError, "The archive does not contain a DBF file" unless dbf_entry

          shp_entry = archive.entries.find { |candidate| candidate.name.downcase.end_with?(".shp") }
          validate_projection!(archive) if shp_entry
          relevant_at ||= dbf_entry.time
          rows = DbfReader.new(dbf_entry.get_input_stream).each_record
          geometries = shp_entry && ShpReader.new(shp_entry.get_input_stream).each

          rows.each do |row|
            geometry_wkt = next_geometry(geometries)
            next unless row

            import.records_seen += 1
            attributes = property_attributes(row, relevant_at, geometry_wkt.present?)
            next unless attributes

            identifier = attributes.fetch(:cadastral_identifier)
            identifiers << identifier
            batch << attributes
            geometry_batch << [ identifier, geometry_wkt ] if geometry_wkt
            flush(batch, geometry_batch) if batch.length >= BATCH_SIZE
          end
        end

        raise ArgumentError, "The archive contained no valid cadastral properties" if identifiers.empty?

        flush(batch, geometry_batch)
        CadastralProperty.transaction do
          CadastralProperty.where(source_archive_key: @source_archive_key)
            .where.not(cadastral_identifier: identifiers).delete_all
          import.update!(
            status: "succeeded", completed_at: Time.current, relevant_at:,
            records_imported: identifiers.uniq.length
          )
        end
      end

      def next_geometry(geometries)
        geometries&.next
      rescue StopIteration
        raise ArgumentError, "The SHP and DBF record counts do not match"
      end

      def property_attributes(row, relevant_at, has_geometry)
        identifier = CadastralIdentifier.new(row["cadnum"])
        return unless identifier.valid? && identifier.level.to_s == @identifier_level

        common_attributes(row, relevant_at, has_geometry).merge(kind_attributes(row))
      end

      def common_attributes(row, relevant_at, has_geometry)
        {
          cadastral_identifier: row.fetch("cadnum"),
          identifier_level: @identifier_level,
          outline_area_sqm: decimal(row["AREA"]),
          perimeter_m: decimal(row["PERIM"]),
          settlement_name: row["ekattefn"].presence,
          address: row["immaddr"].presence,
          district: row["regname"].presence,
          locality: row["quarname"].presence,
          old_identifier: row["oldident"].presence,
          ownership_code: row["propcode"].presence,
          ownership_type: row["proptype"].presence,
          validation_document: row["validate"].presence,
          place: row["place"].presence,
          street_name: row["strename"].presence,
          street_number: row["strnum"].presence,
          source_archive_key: @source_archive_key,
          source_url: @source_url,
          source_relevant_at: relevant_at,
          properties: component_properties(row).tap do |properties|
            properties["source_crs"] = SOURCE_CRS if has_geometry
          end
        }
      end

      def kind_attributes(row)
        case @archive_kind
        when :individual_objects then individual_object_attributes(row)
        when :buildings then building_attributes(row)
        when :parcels then parcel_attributes(row)
        end
      end

      def individual_object_attributes(row)
        {
          area_sqm: decimal(row["apparea"]),
          object_number: row["appnum"].presence,
          floor: row["flrnum"].presence || row["addrflr"].presence,
          address_floor: row["addrflr"].presence,
          levels_count: integer(row["flrcount"]),
          entrance: row["entrance"].presence,
          block_number: row["blocknum"].presence,
          purpose: row["apptype"].presence,
          purpose_code: row["appcode"].presence,
          additional_parts: row["adjpart"].presence
        }
      end

      def building_attributes(row)
        {
          area_sqm: decimal(row["AREA"]),
          purpose: row["functype"].presence,
          purpose_code: row["funccode"].presence,
          floors_count: integer(row["flrcount"]),
          objects_count: integer(row["appcount"])
        }
      end

      def parcel_attributes(row)
        {
          area_sqm: decimal(row["AREA"]),
          category_type: row["cattype"].presence,
          regulation_parcel: row["parcel"].presence,
          territory_code: row["purpcode"].presence,
          territory_type: row["purptype"].presence,
          quarter: row["quarter"].presence,
          permanent_use_code: row["usecode"].presence,
          permanent_use: row["usetype"].presence
        }
      end

      def component_properties(row)
        {
          "settlement_code" => row["ekatte"].presence,
          "cadastre_area_code" => row["cadreg"].presence,
          "parcel_number" => row["cadimm"].presence,
          "building_number" => row["cadbuild"].presence,
          "object_number" => row["cadapp"].presence
        }.compact
      end

      def validate_projection!(archive)
        entry = archive.entries.find { |candidate| candidate.name.downcase.end_with?(".prj") }
        projection = entry&.get_input_stream&.read.to_s
        return if projection.include?("BGS2005") && projection.include?("Lambert_Conformal_Conic")

        raise ArgumentError, "The cadastral SHP projection is not BGS2005 / CCS2005"
      end

      def flush(batch, geometry_batch)
        return if batch.empty?

        unique_batch = batch.index_by { |attributes| attributes.fetch(:cadastral_identifier) }.values
        CadastralProperty.upsert_all(
          unique_batch, unique_by: :index_cadastral_properties_on_cadastral_identifier,
          record_timestamps: true
        )
        persist_geometries(geometry_batch)
        batch.clear
        geometry_batch.clear
      end

      def persist_geometries(rows)
        return if rows.empty?

        connection = CadastralProperty.connection
        values = rows.to_h.map do |identifier, wkt|
          "(#{connection.quote(identifier)}, #{connection.quote(wkt)})"
        end.join(",")
        connection.execute(<<~SQL.squish)
          WITH input(cadastral_identifier, rings) AS (VALUES #{values}),
          built AS (
            SELECT cadastral_identifier,
              ST_Multi(ST_BuildArea(ST_GeomFromText(rings, 7801))) AS source_geometry
            FROM input
          )
          UPDATE cadastral_properties
          SET source_geometry = built.source_geometry,
              geometry = ST_Transform(built.source_geometry, 4326)
          FROM built
          WHERE cadastral_properties.cadastral_identifier = built.cadastral_identifier
        SQL
      end

      def decimal(value)
        BigDecimal(value, exception: false)&.round(2)
      end

      def integer(value)
        Integer(value, exception: false)
      end
    end
  end
end
