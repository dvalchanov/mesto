module DataSources
  module SourceArchives
    module CanonicalJson
      def self.dump(value)
        JSON.generate(normalize(value))
      end

      def self.normalize(value)
        case value
        when Hash
          value.keys.sort_by(&:to_s).to_h { |key| [ key.to_s, normalize(value.fetch(key)) ] }
        when Array
          value.map { |item| normalize(item) }
        else
          value
        end
      end
      private_class_method :normalize
    end
  end
end
