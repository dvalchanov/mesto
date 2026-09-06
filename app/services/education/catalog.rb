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

    attr_reader :entries, :sources, :rules, :checklist_items

    def initialize(root: ROOT)
      @root = Pathname(root)
      @files = @root.glob("**/*.yml").sort
      @loaded_at = latest_mtime
      @entries = []
      @sources = []
      @rules = []
      @checklist_items = []
      load_files
      ContentValidator.new(self).validate!
    end

    def stale?
      latest_mtime > @loaded_at
    end

    def published(kind = nil)
      collection = kind ? entries.select { |entry| entry["kind"] == kind.to_s } : entries
      collection.select { |entry| entry["editorial_status"] == "published" }
    end

    def find(key)
      entries.find { |entry| entry["key"] == key.to_s }
    end

    def find_published_by_slug(kind, slug)
      published(kind).find { |entry| entry["slug"] == slug.to_s }
    end

    def source(id)
      sources.find { |source| source["id"] == id.to_s }
    end

    def checklist_item(key)
      checklist_items.find { |item| item["key"] == key.to_s }
    end

    private

    def load_files
      @files.each do |file|
        payload = YAML.safe_load_file(file, permitted_classes: [], permitted_symbols: [], aliases: false) || {}
        entries.concat(Array(payload["entries"]))
        sources.concat(Array(payload["sources"]))
        rules.concat(Array(payload["rules"]))
        checklist_items.concat(Array(payload["checklist_items"]))
      rescue Psych::Exception => error
        raise ContentValidator::InvalidContent, "#{file.relative_path_from(@root)}: #{error.message}"
      end
    end

    def latest_mtime
      @files.filter_map { |file| file.mtime.to_f if file.exist? }.max || 0
    end
  end
end
