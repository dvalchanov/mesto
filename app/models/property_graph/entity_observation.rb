module PropertyGraph
  class EntityObservation < ApplicationRecord
    CLAIM_ORIGINS = %w[public_source uploaded_document synthetic_demo].freeze

    belongs_to :property_graph_entity, class_name: "PropertyGraph::Entity", inverse_of: :observations
    belongs_to :property_analysis
    belongs_to :source_run, optional: true

    validates :source_key, :source_url, :source_record_reference, :observed_at, :fingerprint, presence: true
    validates :fingerprint, uniqueness: true
    validates :claim_origin, inclusion: { in: CLAIM_ORIGINS }
  end
end
