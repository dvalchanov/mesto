module DataSources
  module Sofiaplan
    class GeojsonImporter
      NAME_FIELDS = %w[name object_nam ime naimenovanie title].freeze
      ADDRESS_FIELDS = %w[address adres location].freeze

      def initialize(dataset_config:, payload:, source_url:)
        @config = dataset_config.deep_stringify_keys
        @payload = payload
        @source_url = source_url
      end

      def call
        dataset = SpatialDataset.find_or_initialize_by(key: @config.fetch("category"))
        dataset.assign_attributes(
          name: @config.fetch("name"), provider: "Софияплан",
          external_dataset_id: @config.fetch("id"), source_url: @source_url,
          relevant_at: @config["relevant_at"], metadata: @config
        )
        dataset.save!

        checksum = Digest::SHA256.hexdigest(JSON.generate(@payload))
        previous = dataset.dataset_imports.where(status: "succeeded", checksum:).order(completed_at: :desc).first
        return skipped_import(dataset, checksum) if previous

        import = dataset.dataset_imports.create!(status: "running", started_at: Time.current, checksum:)
        upsert_features(dataset, import)
        dataset.update!(last_imported_at: Time.current)
        import.update!(status: "succeeded", completed_at: Time.current)
        import
      rescue StandardError => error
        import&.update!(status: "failed", completed_at: Time.current, error_message: error.message.truncate(500))
        raise
      end

      private

      def skipped_import(dataset, checksum)
        dataset.dataset_imports.create!(
          status: "skipped", started_at: Time.current, completed_at: Time.current, checksum:
        )
      end

      def upsert_features(dataset, import)
        seen = []
        factory = RGeo::Geographic.spherical_factory(srid: 4326)

        SpatialFeature.transaction do
          @payload.fetch("features", []).each_with_index do |feature_hash, index|
            geometry = RGeo::GeoJSON.decode(feature_hash["geometry"], geo_factory: factory, json_parser: :json)
            next unless geometry

            properties = feature_hash.fetch("properties", {}).compact
            external_key = stable_key(feature_hash, properties, index)
            feature = dataset.spatial_features.find_or_initialize_by(external_key:)
            created = feature.new_record?
            feature.assign_attributes(
              category: @config.fetch("category"),
              name: first_value(properties, NAME_FIELDS),
              address: first_value(properties, ADDRESS_FIELDS),
              geometry:, properties:
            )
            changed = feature.changed?
            feature.save!
            seen << external_key
            import.records_seen += 1
            created ? import.records_created += 1 : import.records_updated += 1 if changed
          end

          stale = dataset.spatial_features.where.not(external_key: seen)
          import.records_removed = stale.count
          stale.delete_all
          import.save!
        end
      end

      def stable_key(feature, properties, index)
        feature["id"].presence || properties["id"].presence || properties["objectid"].presence ||
          Digest::SHA256.hexdigest(JSON.generate([ feature["geometry"], properties, index ]))
      end

      def first_value(properties, keys)
        key = keys.find { |candidate| properties[candidate].present? }
        properties[key].to_s.truncate(255) if key
      end
    end
  end
end
