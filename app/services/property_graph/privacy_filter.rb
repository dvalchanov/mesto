module PropertyGraph
  class PrivacyFilter
    FORBIDDEN_KEY_PATTERN = /(?:egn|lnch|personal(?:_|\s)?(?:id|number)|birth(?:_|\s)?date|date(?:_|\s)?of(?:_|\s)?birth|email|phone|address)/i

    def self.call(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, child), filtered|
          next if key.to_s.match?(FORBIDDEN_KEY_PATTERN)

          filtered[key.to_s] = call(child)
        end
      when Array
        value.map { |child| call(child) }
      else
        value
      end
    end
  end
end
