module PropertyGraph
  class Relationship < ApplicationRecord
    TYPES = %w[
      part_of_building building_on_parcel cadastre_right_holder registered_owner previous_registered_owner
      managed_by owned_by beneficially_owned_by related_administrative_act
      related_development related_planning_record named_in_administrative_act
    ].freeze
    STATUSES = %w[exact supported unresolved conflicting].freeze
    VISIBLE_STATUSES = %w[exact supported conflicting].freeze
    CLAIM_ORIGINS = EntityObservation::CLAIM_ORIGINS

    belongs_to :property_analysis
    belongs_to :source_run, optional: true
    belongs_to :subject_entity, class_name: "PropertyGraph::Entity", inverse_of: :outgoing_relationships
    belongs_to :object_entity, class_name: "PropertyGraph::Entity", inverse_of: :incoming_relationships

    validates :relationship_type, inclusion: { in: TYPES }
    validates :status, inclusion: { in: STATUSES }
    validates :claim_origin, inclusion: { in: CLAIM_ORIGINS }
    validates :source_key, :source_url, :source_record_reference, :first_observed_at,
      :last_observed_at, :refresh_scope, :fingerprint, presence: true
    validates :fingerprint, uniqueness: true
    validate :different_endpoints
    validate :validity_order
    validate :observation_order

    scope :evidence_backed, -> { where(status: VISIBLE_STATUSES) }
    scope :current, -> { where(active: true) }
    scope :historical, -> { where(active: false) }

    private

    def different_endpoints
      errors.add(:object_entity, "must differ from the subject") if subject_entity_id == object_entity_id
    end

    def validity_order
      return unless valid_from && valid_until && valid_from > valid_until

      errors.add(:valid_until, "must be on or after valid_from")
    end

    def observation_order
      return unless first_observed_at && last_observed_at && first_observed_at > last_observed_at

      errors.add(:last_observed_at, "must be on or after the first observation")
    end
  end
end
