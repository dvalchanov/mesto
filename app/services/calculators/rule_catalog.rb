require "yaml"

module Calculators
  class RuleCatalog
    ROOT = Rails.root.join("config/financial_rules")

    class RuleNotFound < StandardError; end

    attr_reader :rules

    def initialize(root: ROOT)
      @rules = Pathname(root).glob("*.yml").sort.flat_map do |file|
        Array(YAML.safe_load_file(file, permitted_classes: [], permitted_symbols: [], aliases: false)&.fetch("rules", []))
      end
    end

    def find(key, date: Date.current, municipality: nil)
      date = Date.iso8601(date.to_s)
      candidates = rules.select do |rule|
        rule["key"] == key.to_s &&
          rule["effective_from"].to_s <= date.iso8601 &&
          (rule["effective_to"].blank? || rule["effective_to"].to_s >= date.iso8601) &&
          (municipality.nil? || rule["municipality"].nil? || rule["municipality"] == municipality.to_s)
      end
      candidates.max_by { |rule| [ rule["effective_from"].to_s, rule["version"].to_s ] } ||
        raise(RuleNotFound, "No applicable financial rule for #{key} on #{date}")
    end

    def versions_for(keys, date: Date.current, municipality: nil)
      keys.index_with { |key| find(key, date:, municipality:)["version"] }
    end
  end
end
