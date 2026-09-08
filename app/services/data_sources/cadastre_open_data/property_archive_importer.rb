module DataSources
  module CadastreOpenData
    class PropertyArchiveImporter
      BATCH_SIZE = 500
      IMPORTER_VERSION = 3
      SOURCE_CRS = "EPSG:7801 (BGS2005 / CCS2005)".freeze
      ARCHIVE_LEVELS = {
        individual_objects: "individual_object",
        buildings: "building",
        parcels: "parcel"
      }.freeze

      def initialize(
        archive_path:, source_archive_key:, source_url:, archive_kind:, relevant_at: nil,
        coverage_profile: DataCoverage.profile, source_metadata: {}
      )
        @archive_path = Pathname(archive_path)
        @source_archive_key = source_archive_key
        @source_url = source_url
        @archive_kind = archive_kind.to_sym
        @identifier_level = ARCHIVE_LEVELS.fetch(@archive_kind)
        @relevant_at = relevant_at
        @coverage_profile = coverage_profile
        @source_metadata = source_metadata.to_h.symbolize_keys
      end

      def call
        DataSources::AdvisoryLock.with_lock("cadastre:#{@source_archive_key}:#{scope_digest}") do
          perform_import
        end
      end

      private

      def perform_import
        source_checksum = Digest::SHA256.file(@archive_path).hexdigest
        checksum = Digest::SHA256.hexdigest([ IMPORTER_VERSION, scope_digest, source_checksum ].join(":"))
        previous = CadastreImport.find_by(
          source_archive_key: @source_archive_key,
          source_checksum:,
          importer_version: IMPORTER_VERSION,
          scope_digest:,
          status: "succeeded"
        )
        return previous if previous

        @import = CadastreImport.find_or_initialize_by(
          source_archive_key: @source_archive_key,
          source_checksum:,
          importer_version: IMPORTER_VERSION,
          scope_digest:
        )
        @import.assign_attributes(
          source_url: @source_url,
          checksum:,
          coverage_profile_key: @coverage_profile&.key || "unscoped",
          status: "running",
          started_at: Time.current,
          completed_at: nil,
          records_seen: 0,
          records_imported: 0,
          outcome_counts: {},
          validation_errors: {},
          source_checked_at: @source_metadata[:checked_at] || Time.current,
          source_last_modified_at: @source_metadata[:last_modified_at],
          source_etag: @source_metadata[:etag],
          error_message: nil
        )
        @import.save!
        import_archive(@import)
        @import
      rescue StandardError => error
        @import&.update!(
          status: "failed",
          completed_at: Time.current,
          records_seen: @import.records_seen,
          error_message: error.message.truncate(500)
        )
        raise
      end

      def import_archive(import)
        identifiers = Set.new
        candidate_batch = []
        relevant_at = @relevant_at
        outcomes = Hash.new(0)
        validation_errors = Hash.new(0)

        CadastralProperty.transaction do
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
              unless attributes
                outcomes["invalid_identifier"] += 1
                next
              end

              identifier = attributes.fetch(:cadastral_identifier)
              if identifiers.include?(identifier)
                outcomes["duplicate"] += 1
                next
              end
              identifiers << identifier

              candidate_batch << [ attributes, geometry_wkt ]
              flush_candidates(candidate_batch, outcomes, validation_errors) if candidate_batch.length >= BATCH_SIZE
            end
            ensure_geometry_exhausted!(geometries)
          end

          raise ArgumentError, "The archive contained no records" if import.records_seen.zero?

          flush_candidates(candidate_batch, outcomes, validation_errors)
          import.update!(
            status: "succeeded", completed_at: Time.current, relevant_at:,
            records_imported: outcomes.values_at("created", "updated", "unchanged").sum,
            outcome_counts: outcomes,
            validation_errors:
          )
        end
      end

      def next_geometry(geometries)
        geometries&.next
      rescue StopIteration
        raise ArgumentError, "The SHP and DBF record counts do not match"
      end

      def ensure_geometry_exhausted!(geometries)
        return unless geometries

        geometries.next
        raise ArgumentError, "The SHP and DBF record counts do not match"
      rescue StopIteration
        nil
      end

      def classify_outcome(attributes, property)
        return "created" unless property

        comparable = attributes.except(:properties)
        unchanged = comparable.all? { |key, value| property.public_send(key) == value } &&
          property.properties == attributes.fetch(:properties)
        unchanged ? "unchanged" : "updated"
      end

      def flush_candidates(candidates, outcomes, validation_errors)
        return if candidates.empty?

        identifiers = candidates.map { |attributes, _geometry| attributes.fetch(:cadastral_identifier) }
        existing = CadastralProperty.where(cadastral_identifier: identifiers).index_by(&:cadastral_identifier)
        geometry_states = geometry_states(candidates)
        scoped_without_geometry = scoped_existing_identifiers(candidates, existing)
        batch = []
        geometry_batch = []

        candidates.each do |attributes, geometry_wkt|
          identifier = attributes.fetch(:cadastral_identifier)
          if geometry_wkt
            state = geometry_states.fetch(identifier)
            if state.fetch("reason").present?
              outcomes["rejected"] += 1
              validation_errors[state.fetch("reason")] += 1
              next
            end
            unless state.fetch("supported")
              outcomes["outside_configured_coverage"] += 1
              next
            end
          elsif @coverage_profile && !scoped_without_geometry.include?(identifier)
            outcomes["rejected"] += 1
            validation_errors["missing_geometry_for_scoped_import"] += 1
            next
          end

          validation_errors["missing_geometry"] += 1 unless geometry_wkt
          outcomes[classify_outcome(attributes, existing[identifier])] += 1
          batch << attributes
          geometry_batch << [ identifier, geometry_wkt ] if geometry_wkt
        end

        flush(batch, geometry_batch)
        candidates.clear
      end

      def geometry_states(candidates)
        rows = candidates.filter_map do |attributes, wkt|
          [ attributes.fetch(:cadastral_identifier), wkt ] if wkt
        end
        return {} if rows.empty?

        connection = CadastralProperty.connection
        values = rows.map do |identifier, wkt|
          "(#{connection.quote(identifier)}, #{connection.quote(wkt)})"
        end.join(",")
        scope_check = if @coverage_profile
          "ST_Intersects(ST_GeomFromText(#{connection.quote(@coverage_profile.supporting_geometry_wkt)}, 4326), wgs84)"
        else
          "TRUE"
        end
        result = connection.select_all(<<~SQL.squish)
          WITH input(cadastral_identifier, rings) AS (VALUES #{values}),
          built AS (
            SELECT cadastral_identifier,
              ST_Multi(ST_BuildArea(ST_GeomFromText(rings, 7801))) AS geometry
            FROM input
          ), transformed AS (
            SELECT cadastral_identifier, geometry, ST_Transform(geometry, 4326) AS wgs84
            FROM built
          ), validated AS (
            SELECT cadastral_identifier, wgs84,
              CASE
                WHEN geometry IS NULL OR ST_IsEmpty(geometry) THEN 'empty_geometry'
                WHEN NOT ST_IsValid(geometry) THEN 'invalid_geometry'
                WHEN ST_Area(geometry) <= 0 THEN 'zero_area_geometry'
                WHEN ST_XMin(Box3D(wgs84)) NOT BETWEEN 22 AND 29
                  OR ST_XMax(Box3D(wgs84)) NOT BETWEEN 22 AND 29
                  OR ST_YMin(Box3D(wgs84)) NOT BETWEEN 41 AND 45
                  OR ST_YMax(Box3D(wgs84)) NOT BETWEEN 41 AND 45
                  THEN 'implausible_bulgaria_coordinates'
              END AS reason
            FROM transformed
          )
          SELECT cadastral_identifier, reason,
            (reason IS NULL AND #{scope_check}) AS supported
          FROM validated
        SQL
        result.index_by { |row| row.fetch("cadastral_identifier") }
      end

      def scoped_existing_identifiers(candidates, existing)
        return Set.new unless @coverage_profile

        identifiers = candidates.filter_map do |attributes, wkt|
          identifier = attributes.fetch(:cadastral_identifier)
          identifier if wkt.nil? && existing[identifier]&.geometry
        end
        return Set.new if identifiers.empty?

        CadastralProperty.where(cadastral_identifier: identifiers).where(
          "ST_Intersects(geometry, ST_GeomFromText(?, 4326))",
          @coverage_profile.supporting_geometry_wkt
        ).pluck(:cadastral_identifier).to_set
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

      def scope_digest
        @coverage_profile&.scope_digest || "unscoped"
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
