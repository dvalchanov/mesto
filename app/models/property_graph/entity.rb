module PropertyGraph
  class Entity < ApplicationRecord
    TYPES = %w[
      property building parcel company organization person administrative_act planning_record project
    ].freeze

    has_many :observations,
      class_name: "PropertyGraph::EntityObservation",
      foreign_key: :property_graph_entity_id,
      inverse_of: :property_graph_entity,
      dependent: :destroy
    has_many :outgoing_relationships,
      class_name: "PropertyGraph::Relationship",
      foreign_key: :subject_entity_id,
      inverse_of: :subject_entity,
      dependent: :restrict_with_exception
    has_many :incoming_relationships,
      class_name: "PropertyGraph::Relationship",
      foreign_key: :object_entity_id,
      inverse_of: :object_entity,
      dependent: :restrict_with_exception

    validates :entity_type, inclusion: { in: TYPES }
    validates :canonical_key, :display_name, :first_observed_at, :last_observed_at, presence: true
    validates :canonical_key, uniqueness: true
    validate :observation_order

    scope :companies, -> { where(entity_type: "company") }

    private

    def observation_order
      return unless first_observed_at && last_observed_at && first_observed_at > last_observed_at

      errors.add(:last_observed_at, "must be on or after the first observation")
    end
  end
end
