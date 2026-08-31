module DataSources
  module Nag
    class DetailParser
      LABEL_MAP = {
        "идентификатор кккр" => "cadastral_identifiers",
        "кккр идентификатор" => "cadastral_identifiers",
        "адрес" => "address",
        "местност" => "locality",
        "упи" => "upi",
        "дата на издаване" => "issued_on",
        "влязъл в сила" => "effective_on",
        "категория на строежа" => "construction_category",
        "застроена площ" => "built_up_area",
        "разгъната застроена площ" => "gross_floor_area",
        "описание" => "object_description"
      }.freeze

      def parse(html)
        document = Nokogiri::HTML5(html)
        pairs = fixture_pairs(document)
        pairs = semantic_pairs(document) if pairs.empty?
        normalize(pairs)
      end

      private

      def fixture_pairs(document)
        document.css("[data-detail-field]").to_h { |node| [ node["data-detail-field"], node.text.strip ] }
      end

      def semantic_pairs(document)
        pairs = {}
        document.css("dt").each do |label|
          value = label.xpath("following-sibling::dd[1]").first
          add_pair(pairs, label.text, value&.text)
        end
        document.css("tr").each do |row|
          cells = row.css("th,td")
          add_pair(pairs, cells[0]&.text, cells[1]&.text) if cells.length >= 2
        end
        pairs
      end

      def add_pair(pairs, label, value)
        normalized_label = label.to_s.downcase.gsub(/\s+/, " ").strip.delete_suffix(":")
        mapping = LABEL_MAP.find { |candidate, _| normalized_label.include?(candidate) }&.last
        pairs[mapping] = value.to_s.strip if mapping && value.present?
      end

      def normalize(pairs)
        result = pairs.compact_blank
        identifiers = result["cadastral_identifiers"].to_s.scan(/\b\d{5}(?:\.\d+){2,4}\b/).uniq
        result["cadastral_identifiers"] = identifiers if identifiers.any?
        result
      end
    end
  end
end
