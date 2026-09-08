module Analysis
  class PreparedDataRevisionSet
    def self.call(profile:, identifiers: [])
      spatial = SpatialDataset.prepared.where(coverage_profile_key: profile.key).to_h do |dataset|
        [ "spatial:#{dataset.key}", [ dataset.importer_version, dataset.revision_key ] ]
      end
      snapshots = SourceSnapshot.for_profile(profile).group_by(&:source_key).to_h do |source_key, records|
        snapshot = records.max_by(&:created_at)
        [ "source:#{source_key}", snapshot.revision.presence || snapshot.checksum.presence || snapshot.fetched_at&.iso8601 ]
      end
      cadastral = CadastralProperty.where(cadastral_identifier: Array(identifiers).compact)
        .pluck(:cadastral_identifier, :updated_at)
        .to_h { |identifier, updated_at| [ "cadastre:#{identifier}", updated_at.iso8601(6) ] }
      spatial.merge(snapshots).merge(cadastral).compact
    end
  end
end
