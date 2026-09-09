require "yaml"

module Education
  class Catalog
    ROOT = Rails.root.join("content/education")

    class << self
      def instance
        @instance = new if @instance.nil? || (Rails.env.development? && @instance.stale?)
        @instance
      end

      def reset!
        @instance = nil
      end
    end

    attr_reader :entries, :sources, :all_rules, :checklist_items

    def initialize(root: ROOT)
      @root = Pathname(root)
      @files = @root.glob("**/*.yml").sort
      @loaded_at = latest_mtime
      @entries = []
      @sources = []
      @all_rules = []
      @checklist_items = []
      load_files
      ContentValidator.new(self).validate!
    end

    def stale?
      latest_mtime > @loaded_at
    end

    def published(kind = nil, locale: I18n.locale)
      collection = localized_collection(entries, locale:)
      collection = collection.select { |entry| entry["kind"] == kind.to_s } if kind
      collection.select { |entry| entry["editorial_status"] == "published" }
    end

    def find(key, locale: I18n.locale)
      localized_find(entries, "key", key, locale:)
    end

    def find_published_by_slug(kind, slug, locale: I18n.locale)
      published(kind, locale:).find { |entry| entry["slug"] == slug.to_s }
    end

    def source(id, locale: I18n.locale)
      localized_find(sources, "id", id, locale:)
    end

    def rules(locale: I18n.locale)
      localized_collection(all_rules, locale:)
    end

    def checklist_item(key, locale: I18n.locale)
      localized_find(checklist_items, "key", key, locale:)
    end

    private

    def load_files
      @files.each do |file|
        payload = YAML.safe_load_file(file, permitted_classes: [], permitted_symbols: [], aliases: false) || {}
        entries.concat(Array(payload["entries"]))
        sources.concat(Array(payload["sources"]))
        all_rules.concat(Array(payload["rules"]))
        checklist_items.concat(Array(payload["checklist_items"]))
      rescue Psych::Exception => error
        raise ContentValidator::InvalidContent, "#{file.relative_path_from(@root)}: #{error.message}"
      end
    end

    def latest_mtime
      @files.filter_map { |file| file.mtime.to_f if file.exist? }.max || 0
    end

    def localized_find(collection, identity_field, identity, locale:)
      requested_locale = locale.to_s
      collection.find { |item| item[identity_field] == identity.to_s && content_locale(item) == requested_locale } ||
        collection.find { |item| item[identity_field] == identity.to_s && content_locale(item) == I18n.default_locale.to_s }
    end

    def localized_collection(collection, locale:)
      requested_locale = locale.to_s
      fallback_locale = I18n.default_locale.to_s
      fallback = collection.select { |item| content_locale(item) == fallback_locale }
      return fallback if requested_locale == fallback_locale

      requested = collection.select { |item| content_locale(item) == requested_locale }
      identity_field = collection.any? { |item| item.key?("id") } ? "id" : "key"
      requested_by_identity = requested.index_by { |item| item[identity_field] }
      fallback.map { |item| requested_by_identity.delete(item[identity_field]) || item } + requested_by_identity.values
    end

    def content_locale(item)
      item["locale"].presence || I18n.default_locale.to_s
    end
  end
end
