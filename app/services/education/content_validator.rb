module Education
  class ContentValidator
    class InvalidContent < StandardError; end

    ENTRY_FIELDS = %w[key slug kind locale title summary source_ids source_checked_at content_version editorial_status professional_review_status].freeze
    REQUIRED_SECTIONS = {
      "stage" => %w[concise_answer key_points physical documents importance not_meaning discover verify helpers next],
      "document" => %w[what when who why establishes not_establish compare before_after payment availability where professional_review],
      "term" => %w[definition example confusion importance related],
      "guide" => %w[understand verify documents money risks professionals act next buyer_checks]
    }.freeze
    MINIMUM_SECTION_CONTENT = { "stage" => 2_500, "document" => 2_600, "term" => 500, "guide" => 2_600 }.freeze
    TERM_CATEGORIES = %w[cadastre_identity ownership_rights transaction_risk construction handover_operation].freeze
    DOCUMENT_CATEGORIES = %w[planning_construction property_identity agreements_finance handover_operation].freeze
    GUIDE_CATEGORIES = %w[buyer_journey property_type].freeze
    REFERENCE_FIELDS = %w[related_stage_keys related_document_keys related_term_keys].freeze
    CONDITION_KEYS = %w[buyer_stage property_type evidenced_milestone reported_milestone financing_context source_coverage property_connected].freeze

    def initialize(catalog)
      @catalog = catalog
      @errors = []
    end

    def validate!
      validate_unique(group_by_locale(@catalog.entries), "key")
      validate_unique(@catalog.entries.group_by { |entry| [ content_locale(entry), entry["kind"] ] }.values, "slug")
      validate_unique(group_by_locale(@catalog.sources), "id")
      validate_unique(group_by_locale(@catalog.checklist_items), "key")
      validate_unique(group_by_locale(@catalog.all_rules), "key")
      @catalog.entries.each { |entry| validate_entry(entry) }
      validate_guide_coverage
      @catalog.all_rules.each { |rule| validate_rule(rule) }
      validate_checklist_references
      validate_locale_coverage
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
      @errors << "#{entry['key']} uses an unsupported locale" unless I18n.available_locales.map(&:to_s).include?(entry["locale"])
      if entry["kind"] == "term" && !TERM_CATEGORIES.include?(entry["category"])
        @errors << "#{entry['key']} must use a supported term category"
      end
      if entry["kind"] == "document" && !DOCUMENT_CATEGORIES.include?(entry["category"])
        @errors << "#{entry['key']} must use a supported document category"
      end
      if entry["kind"] == "guide" && !GUIDE_CATEGORIES.include?(entry["category"])
        @errors << "#{entry['key']} must use a supported guide category"
      end
      if entry["kind"] == "guide" && entry["category"] == "buyer_journey" && !BuyerJourney::GUIDED_BUYER_STAGES.include?(entry["buyer_stage"])
        @errors << "#{entry['key']} must map to a guided buyer stage"
      end
      if entry["kind"] == "guide" && entry["category"] == "property_type" && Array(entry["property_types"]).blank?
        @errors << "#{entry['key']} must map to at least one property type"
      end
      Array(REQUIRED_SECTIONS[entry["kind"]]).each do |section|
        @errors << "#{entry['key']} missing section #{section}" if entry.dig("sections", section).blank?
      end
      validate_editorial_depth(entry) if entry["locale"] == I18n.default_locale.to_s
      Array(entry["source_ids"]).each do |source_id|
        @errors << "#{entry['key']} references unknown source #{source_id}" unless @catalog.source(source_id, locale: entry["locale"])
      end
      REFERENCE_FIELDS.each do |field|
        Array(entry[field]).each do |key|
          @errors << "#{entry['key']} references unknown content #{key}" unless @catalog.find(key, locale: entry["locale"])
        end
      end
    end

    def validate_editorial_depth(entry)
      minimum = MINIMUM_SECTION_CONTENT[entry["kind"]]
      return unless minimum

      length = entry.fetch("sections", {}).values.flatten.join(" ").length
      @errors << "#{entry['key']} needs more substantive section content (#{length}/#{minimum})" if length < minimum
      if entry["kind"] == "document" && Array(entry.dig("sections", "buyer_checks")).length < 4
        @errors << "#{entry['key']} needs at least four buyer checks"
      end
      if entry["kind"] == "guide" && Array(entry.dig("sections", "buyer_checks")).length < 5
        @errors << "#{entry['key']} needs at least five buyer checks"
      end
      return unless entry["kind"] == "stage"

      @errors << "#{entry['key']} needs at least five practical checks" if Array(entry.dig("sections", "verify")).length < 5
    end

    def validate_guide_coverage
      group_by_locale(@catalog.entries).each do |journey_entries|
        journey_guides = journey_entries.select { |entry| entry["kind"] == "guide" && entry["category"] == "buyer_journey" }
        mapped_stages = journey_guides.map { |entry| entry["buyer_stage"] }
        missing_stages = BuyerJourney::GUIDED_BUYER_STAGES - mapped_stages
        duplicate_stages = mapped_stages.tally.select { |_, count| count > 1 }.keys
        locale = content_locale(journey_entries.first)
        @errors << "Missing buyer guides for #{locale}: #{missing_stages.join(', ')}" if missing_stages.any?
        @errors << "Duplicate buyer guides for #{locale}: #{duplicate_stages.join(', ')}" if duplicate_stages.any?
      end
    end

    def validate_rule(rule)
      unknown_conditions = rule.fetch("when", {}).keys - CONDITION_KEYS
      @errors << "#{rule['key']} has unsupported conditions: #{unknown_conditions.join(', ')}" if unknown_conditions.any?
      Array(rule.dig("then", "lesson_keys")).each do |key|
        @errors << "#{rule['key']} references unknown lesson #{key}" unless @catalog.find(key, locale: content_locale(rule))
      end
      Array(rule.dig("then", "task_keys")).each do |key|
        @errors << "#{rule['key']} references unknown task #{key}" unless @catalog.checklist_item(key, locale: content_locale(rule))
      end
    end

    def validate_checklist_references
      @catalog.checklist_items.each do |item|
        Array(item["related_content_keys"]).each do |key|
          @errors << "#{item['key']} references unknown content #{key}" unless @catalog.find(key, locale: content_locale(item))
        end
      end
    end

    def validate_locale_coverage
      expected_locales = I18n.available_locales.map(&:to_s)
      {
        "content" => [ @catalog.entries, "key" ],
        "source" => [ @catalog.sources, "id" ],
        "rule" => [ @catalog.all_rules, "key" ],
        "checklist item" => [ @catalog.checklist_items, "key" ]
      }.each do |label, (collection, identity_field)|
        collection.group_by { |item| item[identity_field] }.each do |identity, versions|
          missing = expected_locales - versions.map { |item| content_locale(item) }
          @errors << "#{label} #{identity} is missing locales: #{missing.join(', ')}" if missing.any?
        end
      end
    end

    def group_by_locale(collection)
      collection.group_by { |item| content_locale(item) }.values
    end

    def content_locale(item)
      item["locale"].presence || I18n.default_locale.to_s
    end
  end
end
