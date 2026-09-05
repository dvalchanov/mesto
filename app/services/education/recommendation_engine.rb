module Education
  class RecommendationEngine
    def initialize(context, catalog: Catalog.instance)
      @catalog = catalog
      @rules = RuleEngine.new(context, catalog:).matches
    end

    def call(limit: 5)
      seen = Set.new
      @rules.flat_map do |rule|
        Array(rule.dig("then", "lesson_keys")).filter_map do |key|
          next if seen.include?(key)

          entry = @catalog.find(key)
          next unless entry

          seen << key
          {
            "key" => key,
            "title" => entry["title"],
            "summary" => entry["summary"],
            "reason" => rule.dig("then", "reason"),
            "priority" => rule.fetch("priority", 100),
            "path_kind" => entry["kind"],
            "slug" => entry["slug"]
          }
        end
      end.first(limit)
    end
  end
end
