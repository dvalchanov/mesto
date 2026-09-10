module PropertyGraph
  class EntityResolver
    def self.call(...) = new.call(...)

    def call(entity_type:, canonical_key:, display_name:, identifiers: {}, observed_at: Time.current)
      safe_identifiers = entity_type == "person" ? {} : PrivacyFilter.call(identifiers.to_h)
      Entity.transaction do
        entity = Entity.lock.find_or_initialize_by(canonical_key: canonical_key.to_s)
        if entity.persisted? && entity.entity_type != entity_type.to_s
          raise ArgumentError, "Canonical key #{canonical_key} is already assigned to another entity type"
        end

        entity.entity_type = entity_type.to_s
        entity.display_name = display_name.to_s.strip.presence || canonical_key.to_s
        entity.identifiers = entity.identifiers.to_h.merge(safe_identifiers)
        entity.first_observed_at = [ entity.first_observed_at, observed_at ].compact.min
        entity.last_observed_at = [ entity.last_observed_at, observed_at ].compact.max
        entity.save!
        entity
      end
    end
  end
end
