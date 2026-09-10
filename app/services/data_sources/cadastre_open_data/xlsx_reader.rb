module DataSources
  module CadastreOpenData
    class XlsxReader
      def initialize(workbook_path)
        @workbook_path = Pathname(workbook_path)
      end

      def each_row
        return enum_for(:each_row) unless block_given?

        Zip::File.open(@workbook_path) do |workbook|
          worksheet = workbook.entries.find { |entry| entry.name.match?(%r{\Axl/worksheets/[^/]+\.xml\z}i) }
          raise ArgumentError, "The XLSX workbook does not contain a worksheet" unless worksheet

          shared_strings = read_shared_strings(workbook)
          headers = nil
          reader = Nokogiri::XML::Reader(worksheet.get_input_stream)
          reader.each do |node|
            next unless node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT && node.name == "row"

            values = values_for_row(node.outer_xml, shared_strings)
            if headers.nil?
              headers = values.map { |value| normalize_header(value) }
              next
            end

            yield headers.each_with_index.to_h { |header, index| [ header, values[index] ] }
          end
        end
      end

      private

      def read_shared_strings(workbook)
        entry = workbook.find_entry("xl/sharedStrings.xml")
        return [] unless entry

        document = Nokogiri::XML(entry.get_input_stream) { |config| config.strict.nonet }
        document.xpath("//*[local-name()='si']").map do |node|
          node.xpath(".//*[local-name()='t']").map(&:text).join
        end
      end

      def values_for_row(xml, shared_strings)
        document = Nokogiri::XML(xml) { |config| config.strict.nonet }
        values = []
        document.xpath("//*[local-name()='c']").each do |cell|
          index = column_index(cell["r"])
          raw = if cell["t"] == "inlineStr"
            cell.xpath(".//*[local-name()='t']").map(&:text).join
          else
            cell.at_xpath("./*[local-name()='v']")&.text
          end
          shared_index = Integer(raw, exception: false) if cell["t"] == "s"
          values[index] = shared_index ? shared_strings[shared_index] : raw
        end
        values
      end

      def column_index(reference)
        letters = reference.to_s[/\A[A-Z]+/]
        raise ArgumentError, "The XLSX cell has no valid reference" unless letters

        letters.each_byte.reduce(0) { |value, byte| (value * 26) + byte - 64 } - 1
      end

      def normalize_header(value)
        value.to_s.delete_prefix("\uFEFF").squish.downcase
      end
    end
  end
end
