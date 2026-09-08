module DataSources
  module Sofiaplan
    class GeojsonImporter
      IMPORTER_VERSION = 2
      NAME_FIELDS = %w[name object_nam ime naimenovanie title].freeze
      ADDRESS_FIELDS = %w[address adres location].freeze

      def initialize(dataset_config:, payload:, source_url:, coverage_profile: DataCoverage.profile, relevant_at: nil)
        @config = dataset_config.deep_stringify_keys
        @payload = payload
        @source_url = source_url
        @coverage_profile = coverage_profile
        @relevant_at = relevant_at
      end

      def call
        DataSources::AdvisoryLock.with_lock("spatial:#{dataset_key}:#{scope_digest}") do
          import_dataset
        end
      end

      private

      def import_dataset
        dataset = SpatialDataset.find_or_initialize_by(key: dataset_key)
        dataset.assign_attributes(
          name: @config.fetch("name"), provider: @config.fetch("provider", "Софияплан"),
          external_dataset_id: @config["id"], source_url: @source_url,
          relevant_at: @relevant_at || @config["relevant_at"], metadata: @config,
          coverage_profile_key: @coverage_profile&.key,
          coverage_geometry: @coverage_profile&.supporting_geometry,
          importer_version: IMPORTER_VERSION,
          coverage_status: @config.fetch("coverage_status", "partial"),
          permission_status: @config.fetch("permission_status", "review_required"),
          attribution: @config["attribution"],
          permission_reference: @config["permission_reference"]
        )
        dataset.save!

        checksum = Digest::SHA256.hexdigest(JSON.generate(@payload))
        previous = dataset.dataset_imports.where(
          status: "succeeded", checksum:, importer_version: IMPORTER_VERSION, scope_digest:
        ).order(completed_at: :desc).first
        return skipped_import(dataset, checksum) if previous

        import = dataset.dataset_imports.create!(
          status: "running", started_at: Time.current, checksum:,
          importer_version: IMPORTER_VERSION,
          coverage_profile_key: @coverage_profile&.key,
          scope_digest:,
          relevant_at: @relevant_at || @config["relevant_at"]
        )
        upsert_features(dataset, import)
        dataset.update!(
          last_imported_at: Time.current,
          source_checksum: checksum,
          source_revision: @config["source_revision"]
        )
        import.update!(status: "succeeded", completed_at: Time.current)
        import
      rescue StandardError => error
        import&.update!(status: "failed", completed_at: Time.current, error_message: error.message.truncate(500))
        raise
      end

      def skipped_import(dataset, checksum)
        dataset.dataset_imports.create!(
          status: "skipped", started_at: Time.current, completed_at: Time.current, checksum:,
          importer_version: IMPORTER_VERSION,
          coverage_profile_key: @coverage_profile&.key,
          scope_digest:,
          relevant_at: @relevant_at || @config["relevant_at"],
          outcome_counts: { "unchanged_snapshot" => @payload.fetch("features", []).length }
        )
      end

      def upsert_features(dataset, import)
        factory = RGeo::Geographic.spherical_factory(srid: 4326)
        outcomes = Hash.new(0)

        SpatialFeature.transaction do
          @payload.fetch("features", []).each_with_index do |feature_hash, index|
            import.records_seen += 1
            geometry = RGeo::GeoJSON.decode(feature_hash["geometry"], geo_factory: factory, json_parser: :json)
            unless geometry
              outcomes["missing_geometry"] += 1
              next
            end
            if @coverage_profile && !@coverage_profile.supports_geometry_wkt?(geometry.as_text)
              outcomes["outside_configured_coverage"] += 1
              next
            end

            properties = feature_hash.fetch("properties", {}).compact
            external_key = stable_key(feature_hash, properties, index)
            feature = dataset.spatial_features.find_or_initialize_by(external_key:)
            created = feature.new_record?
            feature.assign_attributes(
              category: properties.delete("_mesto_category") || @config.fetch("category"),
              name: first_value(properties, NAME_FIELDS),
              address: first_value(properties, ADDRESS_FIELDS),
              geometry:, properties:
            )
            changed = feature.changed?
            feature.save!
            if created
              import.records_created += 1
              outcomes["created"] += 1
            elsif changed
              import.records_updated += 1
              outcomes["updated"] += 1
            else
              outcomes["unchanged"] += 1
            end
          rescue KeyError, TypeError
            outcomes["invalid_geometry"] += 1
          end

          # Existing records are retained until an explicit, confirmed prune.
          # A failed or scoped refresh must never erase the last usable dataset.
          import.outcome_counts = outcomes
          import.save!
        end
      end

      def dataset_key
        @config["key"] || @config.fetch("category")
      end

      def scope_digest
        @coverage_profile&.scope_digest || "unscoped"
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
