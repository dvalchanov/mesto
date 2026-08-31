module DataSources
  module Nag
    class RegistryParser
      PERSONAL_FIELDS = %w[Employer Applicant ApplicantName Owner ConstructionalOversightName].freeze

      def initialize(registry_kind:, base_url:)
        @registry_kind = registry_kind
        @base_url = base_url
      end

      def parse(html)
        document = Nokogiri::HTML5(html)
        fixture_records = document.css("[data-property-record]")
        records = if fixture_records.any?
          fixture_records.map { |node| parse_fixture_node(node) }
        else
          parse_kendo_payloads(document)
        end

        records.map { |record| normalize(record) }.compact
      end

      private

      def parse_fixture_node(node)
        node.element_children.to_h { |child| [ child["data-field"], child.text.strip ] }
      end

      def parse_kendo_payloads(document)
        document.css("script").filter_map do |script|
          text = script.text
          marker = text.index('"data":{"Data":')
          next unless marker

          json_start = text.index("{", marker + '"data":'.length)
          json = balanced_json(text, json_start)
          JSON.parse(json).fetch("Data", []) if json
        rescue JSON::ParserError
          nil
        end.flatten
      end

      def balanced_json(text, start_index)
        return unless start_index

        depth = 0
        in_string = false
        escaped = false
        text.each_char.with_index do |character, index|
          next if index < start_index

          if in_string
            if escaped
              escaped = false
            elsif character == "\\"
              escaped = true
            elsif character == '"'
              in_string = false
            end
          elsif character == '"'
            in_string = true
          elsif character == "{"
            depth += 1
          elsif character == "}"
            depth -= 1
            return text[start_index..index] if depth.zero?
          end
        end
        nil
      end

      def normalize(raw_record)
        record = raw_record.stringify_keys.except(*PERSONAL_FIELDS)
        external_key = record["Hash"].presence || record["Id"].presence ||
          Digest::SHA256.hexdigest(JSON.generate(record.sort.to_h))
        detail_path = record["DetailUrl"].presence ||
          (record["Hash"].present? ? "/RegisterInfo/Info?url=#{CGI.escape(record.fetch("Hash").to_s)}" : nil)

        {
          "registry_kind" => @registry_kind,
          "external_key" => external_key.to_s,
          "act_number" => first(record, "Number", "RegNumber", "ActNumber"),
          "title" => first(record, "DocumentTypeName", "FileTypeName", "Title", "Type"),
          "status" => first(record, "Status", "State"),
          "issued_on" => date(first_raw(record, "IssuedOn", "IssueDate", "DateFilter", "Date", "FromDate")),
          "effective_on" => date(first_raw(record, "TakeEffectFilter", "EffectiveOn", "Effectivedate")),
          "issuer" => first(record, "Issuer", "IssuedBy"),
          "district" => first(record, "Region", "RegionName", "District"),
          "locality" => first(record, "Terrain", "Locality"),
          "upi" => first(record, "Upi", "UPI"),
          "address" => first(record, "Address", "AdministrativeAddress"),
          "object_description" => first(record, "Object", "Description", "Scope"),
          "construction_category" => first(record, "ConstructionCategory", "Category"),
          "built_up_area" => decimal(first(record, "BuiltUpArea")),
          "gross_floor_area" => decimal(first(record, "GrossFloorArea")),
          "source_url" => detail_path ? URI.join(@base_url, detail_path).to_s : @base_url,
          "document_url" => first(record, "DocumentUrl", "PublicDocumentUrl"),
          "cadastral_identifiers" => identifiers(record.values.join(" ")),
          "longitude" => decimal(first(record, "Longitude", "Lon", "X")),
          "latitude" => decimal(first(record, "Latitude", "Lat", "Y")),
          "properties" => record
        }
      rescue URI::InvalidURIError
        nil
      end

      def first(record, *keys)
        first_raw(record, *keys)&.to_s&.strip
      end

      def first_raw(record, *keys)
        keys.lazy.map { |key| record[key] }.find(&:present?)
      end

      def identifiers(text)
        text.to_s.scan(/\b\d{5}(?:\.\d+){2,4}\b/).uniq
      end

      def date(value)
        return if value.blank?

        milliseconds = value.to_s[/\/Date\((\d+)/, 1]
        return Time.zone.at(milliseconds.to_i / 1_000).to_date if milliseconds

        Date.parse(value.to_s)
      rescue Date::Error
        nil
      end

      def decimal(value)
        return if value.blank?

        BigDecimal(value.to_s.tr(",", "."))
      rescue ArgumentError
        nil
      end
    end
  end
end
