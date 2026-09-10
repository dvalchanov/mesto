module DataSources
  module CadastreOpenData
    class OwnershipArchiveImporter
      BATCH_SIZE = 500
      IMPORTER_VERSION = 1
      ARCHIVE_LEVELS = {
        parcel_rights: "parcel",
        building_rights: "building",
        individual_object_rights: "individual_object"
      }.freeze
      HEADERS = {
        property_type: "вид на имота",
        cadastral_identifier: "кадастрален идентификатор",
        right_code: "код на вида на правото",
        right_type: "вид на правото",
        right_description: "описание на правото",
        holder_identifier: "идентификационен номер на субекта",
        holder_type_code: "код на лицето",
        holder_type: "вид на лицето",
        holder_name: "име на лицето",
        holder_note: "забележка лице",
        document_code: "код на документа",
        document_type: "вид на документа",
        document_description: "описание на документа",
        document_note: "забележка док."
      }.freeze
      NATURAL_PERSON_PATTERN = /физическо\s+лице/i
      PUBLIC_BODY_PATTERN = /държав|община|министерство|ведомство|публичноправ/i
      MASKED_IDENTIFIER_PATTERN = /\A[0-9a-f]{32,}\z/i

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
        DataSources::AdvisoryLock.with_lock("cadastre-rights:#{@source_archive_key}:#{scope_digest}") do
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
        import_archive
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

      def import_archive
        outcomes = Hash.new(0)
        validation_errors = Hash.new(0)
        relevant_at = @relevant_at

        CadastreRight.transaction do
          CadastreRight.where(source_archive_key: @source_archive_key).delete_all
          @record_fingerprints = Set.new
          with_workbook do |workbook_path, workbook_relevant_at|
            relevant_at ||= workbook_relevant_at
            candidates = []
            XlsxReader.new(workbook_path).each_row do |row|
              @import.records_seen += 1
              attributes, outcome = attributes_for(row, relevant_at)
              if attributes
                candidates << attributes
                flush_candidates(candidates, outcomes) if candidates.length >= BATCH_SIZE
              else
                outcomes[outcome] += 1
              end
            end
            flush_candidates(candidates, outcomes)
          end

          raise ArgumentError, "The ownership archive contained no records" if @import.records_seen.zero?

          @import.update!(
            status: "succeeded",
            completed_at: Time.current,
            relevant_at:,
            records_imported: outcomes["imported"],
            outcome_counts: outcomes,
            validation_errors:
          )
        end
      end

      def with_workbook
        workbook = Tempfile.new([ "cadastre-rights", ".xlsx" ])
        workbook.binmode
        Zip::File.open(@archive_path) do |archive|
          entry = archive.entries.find { |candidate| candidate.name.downcase.end_with?(".xlsx") }
          raise ArgumentError, "The ownership archive does not contain an XLSX workbook" unless entry

          IO.copy_stream(entry.get_input_stream, workbook)
          workbook.flush
          yield workbook.path, entry.time
        end
      ensure
        workbook&.close!
      end

      def attributes_for(row, relevant_at)
        values = HEADERS.transform_values { |header| clean(row[header]) }
        identifier = CadastralIdentifier.new(values.fetch(:cadastral_identifier))
        return [ nil, "invalid_identifier" ] unless identifier.valid? && identifier.level.to_s == @identifier_level
        return [ nil, "missing_right" ] if values[:right_type].blank?

        holder = classify_holder(values)
        return [ nil, holder ] if holder.is_a?(String)

        attributes = values.merge(
          cadastral_identifier: identifier.to_s,
          identifier_level: @identifier_level,
          holder_identifier: holder.fetch(:identifier),
          holder_entity_type: holder.fetch(:entity_type),
          source_archive_key: @source_archive_key,
          source_url: @source_url,
          source_relevant_at: relevant_at,
          created_at: Time.current,
          updated_at: Time.current
        )
        attributes[:record_fingerprint] = Digest::SHA256.hexdigest(JSON.generate(
          [ @source_archive_key, attributes.except(:created_at, :updated_at, :source_relevant_at) ]
        ))
        return [ nil, "duplicate" ] unless @record_fingerprints.add?(attributes[:record_fingerprint])

        [ attributes, nil ]
      end

      def classify_holder(values)
        holder_type = values[:holder_type]
        holder_name = values[:holder_name]
        return "missing_holder" if holder_type.blank? || holder_name.blank?
        return "natural_person_omitted" if holder_type.match?(NATURAL_PERSON_PATTERN)

        identifier = BulgarianEik.normalize(values[:holder_identifier])
        if !holder_type.match?(PUBLIC_BODY_PATTERN) && BulgarianEik.valid?(identifier)
          { entity_type: "company", identifier: }
        else
          public_identifier = clean(values[:holder_identifier])
          public_identifier = nil if public_identifier.match?(MASKED_IDENTIFIER_PATTERN)
          { entity_type: "organization", identifier: public_identifier }
        end
      end

      def flush_candidates(candidates, outcomes)
        return if candidates.empty?

        identifiers = candidates.map { |attributes| attributes.fetch(:cadastral_identifier) }.uniq
        prepared = CadastralProperty.where(cadastral_identifier: identifiers).pluck(:cadastral_identifier).to_set
        accepted = candidates.select do |attributes|
          if prepared.include?(attributes.fetch(:cadastral_identifier))
            true
          else
            outcomes["outside_prepared_cadastre"] += 1
            false
          end
        end
        CadastreRight.upsert_all(accepted, unique_by: :record_fingerprint) if accepted.any?
        outcomes["imported"] += accepted.length
        candidates.clear
      end

      def clean(value)
        value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "").squish.presence
      end

      def scope_digest
        @coverage_profile&.scope_digest || "unscoped"
      end
    end
  end
end
