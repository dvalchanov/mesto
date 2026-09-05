module Education
  class RuleEngine
    def initialize(context, catalog: Catalog.instance)
      @context = context.stringify_keys
      @catalog = catalog
    end

    def matches
      @catalog.rules.select { |rule| matches_conditions?(rule.fetch("when", {})) }
        .sort_by { |rule| [ rule.fetch("priority", 100), rule.fetch("key") ] }
    end

    private

    def matches_conditions?(conditions)
      conditions.all? do |key, allowed|
        actual = @context[key]
        Array(allowed).map(&:to_s).include?(actual.to_s)
      end
    end
  end
end
