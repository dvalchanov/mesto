module PropertyGraph
  class Builder
    CADASTRE_LIMITATION = "cadastre_identity_not_ownership"
    CADASTRE_RIGHTS_LIMITATION = "cadastre_rights_snapshot_not_property_register"
    NAG_LIMITATION = "nag_identifier_not_ownership"
    COMPANY_MENTION_LIMITATION = "nag_company_mention_not_ownership"
    PLANNING_LIMITATION = "planning_intersection_limited"

    def initialize(analysis:, observed_at: Time.current)
      @analysis = analysis
      @observed_at = observed_at
      @facts = Analysis::PropertyFactsBuilder.new(analysis:).call
    end

    def call
      build_cadastral_hierarchy
      build_cadastral_rights
      build_administrative_relationships
      build_planning_relationships
      self
    end

    def company_eiks
      Entity.companies.joins(:observations)
        .where(property_graph_entity_observations: { property_analysis_id: @analysis.id })
        .distinct.filter_map { |entity| entity.identifiers["eik"] }
        .select { |eik| BulgarianEik.valid?(eik) }
        .uniq
    end

    private

    def build_cadastral_hierarchy
      entities = @facts.fetch("cadastre_records", {}).to_h.filter_map do |level, record|
        next unless record["cadastral_identifier"].present?

        [ level, cadastral_entity(level, record) ]
      end.to_h
      claims = []
      if entities["individual_object"] && entities["building"]
        claims << hierarchy_claim(
          subject: entities.fetch("individual_object"), object: entities.fetch("building"),
          relationship_type: "part_of_building"
        )
      end
      if entities["building"] && entities["parcel"]
        claims << hierarchy_claim(
          subject: entities.fetch("building"), object: entities.fetch("parcel"),
          relationship_type: "building_on_parcel"
        )
      end
      RelationshipRefresh.new(
        analysis: @analysis,
        source_key: "cadastre",
        refresh_scope: "cadastre:#{@analysis.submitted_identifier}",
        observed_at: @observed_at
      ).call(claims)
    end

    def cadastral_entity(level, record)
      identifier = record.fetch("cadastral_identifier")
      entity = EntityResolver.call(
        entity_type: { "individual_object" => "property", "building" => "building", "parcel" => "parcel" }.fetch(level),
        canonical_key: "cadastre:#{identifier}",
        display_name: identifier,
        identifiers: { "cadastral_identifier" => identifier },
        observed_at: @observed_at
      )
      source_date = parse_time(record["source_relevant_at"]) || cadastre_run&.relevant_at
      ObservationWriter.call(
        entity:,
        analysis: @analysis,
        source_key: "cadastre",
        source_url: record.fetch("source_url"),
        source_record_reference: identifier,
        source_date:,
        observed_at: @observed_at,
        source_run: cadastre_run,
        attributes: record.slice(
          "cadastral_identifier", "identifier_level", "area_sqm", "address", "purpose",
          "floor", "object_number", "levels_count", "permanent_use"
        ).compact,
        evidence: { "basis" => "official_cadastral_record" },
        coverage_limitation: CADASTRE_LIMITATION
      )
      entity
    end

    def hierarchy_claim(subject:, object:, relationship_type:)
      {
        subject_entity: subject,
        object_entity: object,
        relationship_type:,
        status: "exact",
        source_run: cadastre_run,
        source_url: cadastre_run&.source_url || DataSources.config.dig("cadastre", "open_data", "portal_url"),
        source_record_reference: "#{subject.identifiers.fetch('cadastral_identifier')} -> #{object.identifiers.fetch('cadastral_identifier')}",
        source_date: cadastre_run&.relevant_at || parse_time(@facts["cadastre_relevant_at"]),
        subject_scope: subject.identifiers,
        object_scope: object.identifiers,
        evidence: {
          "basis" => "official_cadastral_identifier_hierarchy",
          "not_ownership_evidence" => true
        },
        coverage_limitation: CADASTRE_LIMITATION
      }
    end

    def build_cadastral_rights
      entities = @analysis.identifiers_for_matching.to_h do |identifier|
        [ identifier, Entity.find_by(canonical_key: "cadastre:#{identifier}") ]
      end
      claims = CadastreRight.for_identifiers(entities.keys).order(:id).filter_map do |right|
        subject = entities[right.cadastral_identifier]
        next unless subject

        holder = cadastral_right_holder(right)
        {
          subject_entity: subject,
          object_entity: holder,
          relationship_type: "cadastre_right_holder",
          status: "exact",
          source_run: source_run_for("cadastre_ownership"),
          source_url: right.source_url,
          source_record_reference: cadastre_right_source_reference(right),
          source_date: right.source_relevant_at,
          subject_scope: {
            "cadastral_identifier" => right.cadastral_identifier,
            "identifier_level" => right.identifier_level
          },
          object_scope: holder.identifiers.merge("holder_type" => right.holder_type),
          evidence: {
            "basis" => "exact_agkk_cadastre_right_record",
            "right_code" => right.right_code,
            "right_type" => right.right_type,
            "right_description" => right.right_description,
            "document_code" => right.document_code,
            "document_type" => right.document_type,
            "document_description" => right.document_description,
            "not_property_register_reference" => true
          }.compact,
          coverage_limitation: CADASTRE_RIGHTS_LIMITATION
        }
      end
      RelationshipRefresh.new(
        analysis: @analysis,
        source_key: "cadastre_ownership",
        refresh_scope: "cadastre_ownership:#{@analysis.submitted_identifier}",
        observed_at: @observed_at
      ).call(claims)
    end

    def cadastral_right_holder(right)
      identifiers = if right.holder_identifier.present?
        key = BulgarianEik.valid?(right.holder_identifier) ? "eik" : "registry_identifier"
        { key => right.holder_identifier }
      else
        {}
      end
      canonical_key = if right.holder_entity_type == "company"
        "eik:#{right.holder_identifier}"
      else
        digest = Digest::SHA256.hexdigest(JSON.generate(
          [ right.holder_type, right.holder_name, right.holder_identifier ]
        ))
        "agkk-organization:#{digest}"
      end
      entity = EntityResolver.call(
        entity_type: right.holder_entity_type,
        canonical_key:,
        display_name: right.holder_name,
        identifiers:,
        observed_at: @observed_at
      )
      ObservationWriter.call(
        entity:,
        analysis: @analysis,
        source_key: "cadastre_ownership",
        source_url: right.source_url,
        source_record_reference: cadastre_right_source_reference(right),
        source_date: right.source_relevant_at,
        observed_at: @observed_at,
        source_run: source_run_for("cadastre_ownership"),
        attributes: {
          "legal_name" => right.holder_name,
          "eik" => identifiers["eik"],
          "holder_type" => right.holder_type
        }.compact,
        evidence: {
          "basis" => "exact_agkk_cadastre_right_record",
          "cadastral_identifier" => right.cadastral_identifier
        },
        coverage_limitation: CADASTRE_RIGHTS_LIMITATION
      )
      entity
    end

    def cadastre_right_source_reference(right)
      [
        right.cadastral_identifier,
        right.document_type.presence || right.right_type,
        right.record_fingerprint.first(12)
      ].join(" · ")
    end

    def build_administrative_relationships
      acts_by_kind = @analysis.administrative_acts.includes(:administrative_act_references).group_by(&:registry_kind)
      AdministrativeAct::REGISTRY_KINDS.each do |kind|
        source_key = "nag_#{kind}"
        claims = Array(acts_by_kind[kind]).flat_map { |act| claims_for_act(act, source_key:) }
        RelationshipRefresh.new(
          analysis: @analysis,
          source_key:,
          refresh_scope: "#{source_key}:#{@analysis.submitted_identifier}",
          observed_at: @observed_at
        ).call(claims)
      end
    end

    def build_planning_relationships
      parcel = Entity.find_by(canonical_key: "cadastre:#{@analysis.parcel_identifier}")
      datasets = SpatialDataset.prepared.where(
        key: %w[arcgis_development_potential arcgis_functional_zoning],
        coverage_profile_key: @analysis.coverage_profile_key
      )
      datasets.each do |dataset|
        claims = if parcel && @analysis.parcel_geometry
          dataset.spatial_features.intersecting(@analysis.parcel_geometry).map do |feature|
            planning_claim(parcel:, dataset:, feature:)
          end
        else
          []
        end
        RelationshipRefresh.new(
          analysis: @analysis,
          source_key: dataset.key,
          refresh_scope: "#{dataset.key}:#{@analysis.parcel_identifier}",
          observed_at: @observed_at
        ).call(claims)
      end
    end

    def planning_claim(parcel:, dataset:, feature:)
      entity = EntityResolver.call(
        entity_type: "planning_record",
        canonical_key: "spatial:#{dataset.key}:#{feature.external_key}",
        display_name: feature.name.presence || dataset.name,
        identifiers: { "dataset_key" => dataset.key, "external_key" => feature.external_key },
        observed_at: @observed_at
      )
      source_run = source_run_for(dataset.key)
      ObservationWriter.call(
        entity:,
        analysis: @analysis,
        source_key: dataset.key,
        source_url: dataset.source_url,
        source_record_reference: feature.external_key,
        source_date: dataset.relevant_at,
        observed_at: @observed_at,
        source_run:,
        attributes: {
          "name" => feature.name,
          "category" => feature.category,
          "planning_area" => feature.properties["RegName"],
          "district" => feature.properties["Rajon"],
          "predominant_floors" => feature.properties["Preobl_et"]
        }.compact,
        evidence: { "basis" => "prepared_geometry_intersection", "dataset_revision" => dataset.revision_key },
        coverage_limitation: PLANNING_LIMITATION
      )
      {
        subject_entity: parcel,
        object_entity: entity,
        relationship_type: dataset.key == "arcgis_development_potential" ? "related_development" : "related_planning_record",
        status: "supported",
        source_run:,
        source_url: dataset.source_url,
        source_record_reference: feature.external_key,
        source_date: dataset.relevant_at,
        subject_scope: { "cadastral_identifier" => @analysis.parcel_identifier },
        object_scope: { "dataset_key" => dataset.key, "external_key" => feature.external_key },
        evidence: {
          "basis" => "prepared_geometry_intersection",
          "geometry_basis" => "parcel_polygon",
          "dataset_revision" => dataset.revision_key
        },
        coverage_limitation: PLANNING_LIMITATION
      }
    end

    def claims_for_act(act, source_key:)
      references = act.administrative_act_references.select do |reference|
        reference.match_basis == "document" && reference.cadastral_identifier.in?(@analysis.identifiers_for_matching)
      end
      return [] if references.empty?

      act_entity = administrative_act_entity(act, source_key:)
      relation_claims = references.map do |reference|
        property_entity = cadastral_reference_entity(reference, act:, source_key:)
        {
          subject_entity: property_entity,
          object_entity: act_entity,
          relationship_type: "related_administrative_act",
          status: "exact",
          source_run: source_run_for(source_key),
          source_url: act.source_url,
          source_record_reference: act.external_key,
          source_date: act.issued_on,
          subject_scope: { "cadastral_identifier" => reference.cadastral_identifier },
          object_scope: { "registry_kind" => act.registry_kind, "external_key" => act.external_key },
          evidence: { "basis" => "identifier_in_published_document", "match_basis" => "document" },
          coverage_limitation: NAG_LIMITATION
        }
      end
      relation_claims.concat(company_mention_claims(act, act_entity:, source_key:))
    end

    def administrative_act_entity(act, source_key:)
      entity = EntityResolver.call(
        entity_type: "administrative_act",
        canonical_key: "nag:#{act.registry_kind}:#{act.external_key}",
        display_name: act.act_number.presence || act.title.presence || act.external_key,
        identifiers: { "registry_kind" => act.registry_kind, "external_key" => act.external_key },
        observed_at: @observed_at
      )
      ObservationWriter.call(
        entity:,
        analysis: @analysis,
        source_key:,
        source_url: act.source_url,
        source_record_reference: act.external_key,
        source_date: act.issued_on,
        observed_at: @observed_at,
        source_run: source_run_for(source_key),
        attributes: {
          "act_number" => act.act_number,
          "title" => act.title,
          "status" => act.status,
          "issued_on" => act.issued_on&.iso8601,
          "effective_on" => act.effective_on&.iso8601,
          "issuer" => act.issuer,
          "registry_kind" => act.registry_kind
        }.compact,
        evidence: { "basis" => "published_administrative_record" },
        coverage_limitation: NAG_LIMITATION
      )
      entity
    end

    def cadastral_reference_entity(reference, act:, source_key:)
      level = reference.reference_level
      entity = EntityResolver.call(
        entity_type: { "individual_object" => "property", "building" => "building", "parcel" => "parcel" }.fetch(level),
        canonical_key: "cadastre:#{reference.cadastral_identifier}",
        display_name: reference.cadastral_identifier,
        identifiers: { "cadastral_identifier" => reference.cadastral_identifier },
        observed_at: @observed_at
      )
      ObservationWriter.call(
        entity:,
        analysis: @analysis,
        source_key:,
        source_url: act.source_url,
        source_record_reference: act.external_key,
        source_date: act.issued_on,
        observed_at: @observed_at,
        source_run: source_run_for(source_key),
        attributes: { "cadastral_identifier" => reference.cadastral_identifier },
        evidence: { "basis" => "identifier_in_published_document" },
        coverage_limitation: NAG_LIMITATION
      )
      entity
    end

    def company_mention_claims(act, act_entity:, source_key:)
      Array(act.properties["organization_mentions"]).filter_map do |raw_mention|
        mention = raw_mention.to_h.deep_stringify_keys
        eik = BulgarianEik.normalize(mention["eik"])
        next unless BulgarianEik.valid?(eik) && mention["legal_name"].present?

        company = EntityResolver.call(
          entity_type: "company",
          canonical_key: "eik:#{eik}",
          display_name: mention.fetch("legal_name"),
          identifiers: { "eik" => eik },
          observed_at: @observed_at
        )
        ObservationWriter.call(
          entity: company,
          analysis: @analysis,
          source_key:,
          source_url: act.source_url,
          source_record_reference: act.external_key,
          source_date: act.issued_on,
          observed_at: @observed_at,
          source_run: source_run_for(source_key),
          attributes: { "legal_name" => mention.fetch("legal_name"), "eik" => eik },
          evidence: { "basis" => "company_name_and_eik_in_published_record", "source_role" => mention["source_role"] },
          coverage_limitation: COMPANY_MENTION_LIMITATION
        )
        {
          subject_entity: act_entity,
          object_entity: company,
          relationship_type: "named_in_administrative_act",
          status: "exact",
          source_run: source_run_for(source_key),
          source_url: act.source_url,
          source_record_reference: act.external_key,
          source_date: act.issued_on,
          subject_scope: { "registry_kind" => act.registry_kind, "external_key" => act.external_key },
          object_scope: { "eik" => eik, "source_role" => mention["source_role"] },
          evidence: { "basis" => "company_name_and_eik_in_published_record", "source_role" => mention["source_role"] },
          coverage_limitation: COMPANY_MENTION_LIMITATION
        }
      end
    end

    def cadastre_run = @cadastre_run ||= source_run_for("cadastre")

    def source_run_for(source_key)
      @analysis.current_source_runs.where(source_key:).order(created_at: :desc).first
    end

    def parse_time(value)
      return value if value.respond_to?(:iso8601) && !value.is_a?(String)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
