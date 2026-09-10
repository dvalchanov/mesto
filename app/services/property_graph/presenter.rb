module PropertyGraph
  class Presenter
    NODE_ORDER = %w[property building parcel planning_record project administrative_act company organization person].freeze
    REGISTRY_SOURCE_KEYS = %w[cadastre_ownership property_register commercial_register vies].freeze

    def initialize(analysis:)
      @analysis = analysis
    end

    def call
      relationships = @analysis.property_graph_relationships.evidence_backed
        .includes(:subject_entity, :object_entity).order(active: :desc, source_date: :desc, created_at: :asc).to_a
      observations = @analysis.property_graph_entity_observations.includes(:property_graph_entity)
        .order(:source_date, :observed_at).to_a
      entities = (observations.map(&:property_graph_entity) + relationships.flat_map { |edge| [ edge.subject_entity, edge.object_entity ] }).uniq
      edges = relationships.map { |relationship| serialize_relationship(relationship) }
      nodes = entities.map { |entity| serialize_entity(entity, observations, edges) }
        .sort_by { |node| [ NODE_ORDER.index(node.fetch("entity_type")) || NODE_ORDER.length, node.fetch("display_name") ] }
      {
        "nodes" => nodes,
        "edges" => edges,
        "source_checks" => registry_source_checks,
        "generated_at" => Time.current.iso8601
      }
    end

    private

    def serialize_entity(entity, observations, edges)
      entity_observations = observations.select { |observation| observation.property_graph_entity_id == entity.id }
      attributes = entity_observations.each_with_object({}) do |observation, merged|
        merged.deep_merge!(observation.facts.to_h)
      end
      sources = entity_observations.map do |observation|
        {
          "source_key" => observation.source_key,
          "source_url" => observation.source_url,
          "source_record_reference" => observation.source_record_reference,
          "source_date" => observation.source_date&.iso8601,
          "coverage_limitation" => observation.coverage_limitation,
          "claim_origin" => observation.claim_origin
        }.compact
      end.uniq
      key = entity.canonical_key
      {
        "key" => key,
        "entity_type" => entity.entity_type,
        "display_name" => entity.display_name,
        "identifiers" => PrivacyFilter.call(entity.identifiers),
        "attributes" => PrivacyFilter.call(attributes),
        "sources" => sources,
        "connections" => connections_for(key, edges)
      }
    end

    def serialize_relationship(relationship)
      {
        "key" => relationship.fingerprint,
        "subject_key" => relationship.subject_entity.canonical_key,
        "subject_name" => relationship.subject_entity.display_name,
        "object_key" => relationship.object_entity.canonical_key,
        "object_name" => relationship.object_entity.display_name,
        "relationship_type" => relationship.relationship_type,
        "status" => relationship.status,
        "active" => relationship.active,
        "valid_from" => relationship.valid_from&.iso8601,
        "valid_until" => relationship.valid_until&.iso8601,
        "source_key" => relationship.source_key,
        "source_url" => relationship.source_url,
        "source_record_reference" => relationship.source_record_reference,
        "source_date" => relationship.source_date&.iso8601,
        "first_observed_at" => relationship.first_observed_at.iso8601,
        "last_observed_at" => relationship.last_observed_at.iso8601,
        "subject_scope" => PrivacyFilter.call(relationship.subject_scope),
        "object_scope" => PrivacyFilter.call(relationship.object_scope),
        "evidence" => PrivacyFilter.call(relationship.evidence),
        "coverage_limitation" => relationship.coverage_limitation,
        "claim_origin" => relationship.claim_origin
      }.compact
    end

    def connections_for(key, edges)
      edges.filter_map do |edge|
        if edge["subject_key"] == key
          edge.slice("key", "relationship_type", "status", "active", "object_key", "object_name", "source_key", "source_url", "source_date", "coverage_limitation")
            .merge("direction" => "outgoing", "connected_key" => edge["object_key"], "connected_name" => edge["object_name"])
        elsif edge["object_key"] == key
          edge.slice("key", "relationship_type", "status", "active", "subject_key", "subject_name", "source_key", "source_url", "source_date", "coverage_limitation")
            .merge("direction" => "incoming", "connected_key" => edge["subject_key"], "connected_name" => edge["subject_name"])
        end
      end
    end

    def registry_source_checks
      @analysis.current_source_runs.where(source_key: REGISTRY_SOURCE_KEYS).order(:created_at).map do |run|
        {
          "source_key" => run.source_key,
          "status" => run.status,
          "source_url" => run.source_url,
          "checked_at" => run.fetched_at&.iso8601,
          "relevant_at" => run.relevant_at&.iso8601,
          "eik" => run.request_metadata["eik"],
          "demo_data" => run.request_metadata["demo_data"],
          "reason" => source_check_reason(run)
        }.compact
      end
    end

    def source_check_reason(run)
      return "available" if run.status == "succeeded"
      return "automation_unavailable" if run.error_class == "PublicRegistry::AutomationUnavailable"
      return "no_reliable_eik" if run.error_class == "PublicRegistry::NoReliableIdentifier"

      "failed"
    end
  end
end
