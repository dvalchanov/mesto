module Education
  class ContentValidator
    class InvalidContent < StandardError; end

    ENTRY_FIELDS = %w[key slug kind locale title summary source_ids source_checked_at content_version editorial_status professional_review_status].freeze
    REQUIRED_SECTIONS = {
      "stage" => %w[concise_answer key_points physical documents importance not_meaning discover verify helpers next],
      "document" => %w[what when who why establishes not_establish compare before_after payment availability where professional_review],
      "term" => %w[definition example confusion importance related],
      "guide" => %w[understand verify act next]
    }.freeze
    MINIMUM_SECTION_CONTENT = { "stage" => 2_500, "document" => 1_000, "term" => 500, "guide" => 380 }.freeze
    REFERENCE_FIELDS = %w[related_stage_keys related_document_keys related_term_keys].freeze
    CONDITION_KEYS = %w[buyer_stage property_type evidenced_milestone reported_milestone financing_context source_coverage property_connected].freeze

    def initialize(catalog)
      @catalog = catalog
      @errors = []
    end

    def validate!
      validate_unique(@catalog.entries, "key")
      validate_unique(@catalog.entries.group_by { |entry| entry["kind"] }.values, "slug")
      validate_unique(@catalog.sources, "id")
      validate_unique(@catalog.checklist_items, "key")
      @catalog.entries.each { |entry| validate_entry(entry) }
      @catalog.rules.each { |rule| validate_rule(rule) }
      validate_checklist_references
      raise InvalidContent, @errors.join("\n") if @errors.any?

      true
    end

    private

    def validate_unique(collections, field)
      lists = collections.first.is_a?(Hash) ? [ collections ] : collections
      Array(lists).each do |collection|
        duplicates = collection.filter_map { |item| item[field] }.tally.select { |_, count| count > 1 }.keys
        @errors << "Duplicate #{field}: #{duplicates.join(', ')}" if duplicates.any?
      end
    end

    def validate_entry(entry)
      missing = ENTRY_FIELDS.select { |field| entry[field].blank? }
      @errors << "#{entry['key'] || 'entry'} missing: #{missing.join(', ')}" if missing.any?
      @errors << "#{entry['key']} must use Bulgarian locale" unless entry["locale"] == "bg"
      Array(REQUIRED_SECTIONS[entry["kind"]]).each do |section|
        @errors << "#{entry['key']} missing section #{section}" if entry.dig("sections", section).blank?
      end
      validate_editorial_depth(entry)
      Array(entry["source_ids"]).each do |source_id|
        @errors << "#{entry['key']} references unknown source #{source_id}" unless @catalog.source(source_id)
      end
      REFERENCE_FIELDS.each do |field|
        Array(entry[field]).each do |key|
          @errors << "#{entry['key']} references unknown content #{key}" unless @catalog.find(key)
        end
      end
    end

    def validate_editorial_depth(entry)
      minimum = MINIMUM_SECTION_CONTENT[entry["kind"]]
      return unless minimum

      length = entry.fetch("sections", {}).values.flatten.join(" ").length
      @errors << "#{entry['key']} needs more substantive section content (#{length}/#{minimum})" if length < minimum
      return unless entry["kind"] == "stage"

      @errors << "#{entry['key']} needs at least five practical checks" if Array(entry.dig("sections", "verify")).length < 5
    end

    def validate_rule(rule)
      unknown_conditions = rule.fetch("when", {}).keys - CONDITION_KEYS
      @errors << "#{rule['key']} has unsupported conditions: #{unknown_conditions.join(', ')}" if unknown_conditions.any?
      Array(rule.dig("then", "lesson_keys")).each do |key|
        @errors << "#{rule['key']} references unknown lesson #{key}" unless @catalog.find(key)
      end
      Array(rule.dig("then", "task_keys")).each do |key|
        @errors << "#{rule['key']} references unknown task #{key}" unless @catalog.checklist_item(key)
      end
    end

    def validate_checklist_references
      @catalog.checklist_items.each do |item|
        Array(item["related_content_keys"]).each do |key|
          @errors << "#{item['key']} references unknown content #{key}" unless @catalog.find(key)
        end
      end
    end
  end
end
