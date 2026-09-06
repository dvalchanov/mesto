module Education
  class Search
    def initialize(catalog: Catalog.instance)
      @catalog = catalog
    end

    def call(query, kinds: %w[document term])
      needle = normalize(query)
      return @catalog.published.select { |entry| entry["kind"].in?(kinds) } if needle.blank?

      @catalog.published.filter_map do |entry|
        next unless entry["kind"].in?(kinds)

        values = [ entry["title"], entry["summary"], *Array(entry["aliases"]), *Array(entry["keywords"]) ]
        normalized = values.map { |value| normalize(value) }
        compact = values.map { |value| normalize_compact(value) }
        next unless normalized.any? { |value| value.include?(needle) } || compact.any? { |value| value.include?(needle.delete(" ")) }

        score = normalized.include?(needle) || compact.include?(needle.delete(" ")) ? 0 : 1
        [ score, entry ]
      end.sort_by { |score, entry| [ score, entry["title"] ] }.map(&:last)
    end

    private

    def normalize(value)
      value.to_s.downcase.tr("–—_", "---").gsub(/[^[:alnum:]а-я]+/i, " ").squish
    end

    def normalize_compact(value)
      normalize(value).delete(" ")
    end
  end
end
