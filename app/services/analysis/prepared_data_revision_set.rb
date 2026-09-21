module Analysis
  class PreparedDataRevisionSet
    def self.call(profile:, identifiers: [])
      identifiers = Array(identifiers).compact.map(&:to_s).uniq.sort
      spatial = SpatialDataset.usable.where(coverage_profile_key: profile.key).to_h do |dataset|
        [ "spatial:#{dataset.key}", [ dataset.importer_version, dataset.revision_key ] ]
      end
      scoped_snapshots = SourceSnapshot.for_profile(profile)
      snapshots = scoped_snapshots.distinct.pluck(:source_key).filter_map do |source_key|
        snapshot = if source_key.start_with?("nag_")
          SourceSnapshot.latest_for_identifiers(source_key, identifiers:, profile:)
        else
          scoped_snapshots.where(source_key:).order(created_at: :desc).first
        end
        next unless snapshot

        [ "source:#{source_key}", snapshot.revision.presence || snapshot.checksum.presence || snapshot.fetched_at&.iso8601 ]
      end.to_h
      cadastral = CadastralProperty.usable.where(cadastral_identifier: identifiers)
        .pluck(:cadastral_identifier, :updated_at)
        .to_h { |identifier, updated_at| [ "cadastre:#{identifier}", updated_at.iso8601(6) ] }
      cadastre_rights = identifiers.to_h do |identifier|
        rows = CadastreRight.usable.where(cadastral_identifier: identifier).order(:record_fingerprint)
          .pluck(:record_fingerprint, :updated_at)
          .map { |fingerprint, updated_at| [ fingerprint, updated_at.iso8601(6) ] }
        [ "cadastre-rights:#{identifier}", Digest::SHA256.hexdigest(JSON.generate(rows)) ]
      end
      registry_providers = %w[property_register commercial_register].to_h do |source_key|
        [ "provider:#{source_key}", DataSources.config.dig(source_key, "provider") ]
      end
      spatial.merge(snapshots).merge(cadastral).merge(cadastre_rights).merge(registry_providers).compact
    end
  end
end
