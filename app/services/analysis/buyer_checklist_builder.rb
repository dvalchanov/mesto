module Analysis
  class BuyerChecklistBuilder
    TOPIC_KEYS = {
      "area_missing" => "area_comparison",
      "area_compare" => "area_comparison",
      "location_missing" => "boundaries_access",
      "design_visa" => "design_visa",
      "building_permit" => "building_permit",
      "planning_order" => "zoning_plans",
      "occupancy" => "occupancy",
      "ownership" => "title_chain",
      "encumbrances" => "encumbrances",
      "technical_inspection" => "technical_inspection"
    }.freeze

    REGISTRY_KINDS = {
      "zoning_plans" => "urban_planning_orders",
      "design_visa" => "design_visas",
      "building_permit" => "building_permits",
      "occupancy" => "occupancy_certificates"
    }.freeze

    def initialize(analysis:, facts:, visible_acts: nil)
      @analysis = analysis
      @facts = facts
      @visible_acts = visible_acts&.to_a || default_visible_acts
    end

    def call
      items = []
      items << item("area_missing") unless @facts["subject_area_sqm"]
      items << item("area_compare") if @facts["subject_area_sqm"]
      items << item("location_missing") unless @analysis.centroid
      items.concat(registry_items)
      items << item("occupancy") if @analysis.building_identifier.present?
      items << item("ownership")
      items << item("encumbrances")
      items << item("technical_inspection")
      items.uniq { |entry| entry["key"] }
    end

    private

    def registry_items
      kinds = @visible_acts.map(&:registry_kind).uniq
      result = []
      result << item("design_visa") if kinds.include?("design_visas")
      result << item("building_permit") if kinds.include?("building_permits")
      result << item("planning_order") if kinds.include?("urban_planning_orders")
      result
    end

    def item(key)
      topic_key = TOPIC_KEYS.fetch(key)
      {
        "key" => key,
        "topic_key" => topic_key,
        "lookup_identifier" => lookup_identifier(topic_key),
        "known_facts" => known_facts(topic_key)
      }
    end

    def lookup_identifier(topic_key)
      case topic_key
      when "boundaries_access", "zoning_plans", "design_visa", "building_permit"
        @analysis.parcel_identifier
      when "occupancy"
        @analysis.building_identifier || @analysis.parcel_identifier
      else
        @analysis.submitted_identifier
      end
    end

    def known_facts(topic_key)
      facts = case topic_key
      when "area_comparison"
        subject_identity_facts
      when "boundaries_access"
        parcel_identity_facts
      when "zoning_plans"
        registry_facts(topic_key) + parcel_identity_facts + planning_facts
      when "design_visa", "building_permit"
        registry_facts(topic_key) + parcel_reference_facts
      when "occupancy"
        registry_facts(topic_key) + building_identity_facts
      when "title_chain", "encumbrances"
        deed_identity_facts
      when "technical_inspection"
        technical_reference_facts
      else
        []
      end

      facts.compact.uniq { |fact| [ fact["key"], fact["value"] ] }.first(6)
    end

    def subject_identity_facts
      [
        fact("subject_area", @facts["subject_area_sqm"], format: "area"),
        fact("purpose", @facts["purpose"]),
        fact("position", position_values),
        fact("address", @facts["address"]),
        fact("additional_parts", @facts["additional_parts"]),
        fact("previous_identifier", subject_record["old_identifier"])
      ]
    end

    def parcel_identity_facts
      [
        fact("parcel_area", @facts["parcel_area_sqm"], format: "area"),
        fact("regulated_plot", regulation_values),
        fact("permanent_use", parcel_record["permanent_use"]),
        fact("parcel_address", parcel_record["address"]),
        fact("previous_identifier", parcel_record["old_identifier"])
      ]
    end

    def parcel_reference_facts
      [
        fact("regulated_plot", regulation_values),
        fact("parcel_address", parcel_record["address"]),
        fact("permanent_use", parcel_record["permanent_use"])
      ]
    end

    def building_identity_facts
      [
        fact("building_purpose", building_record["purpose"]),
        fact("building_floors", building_record["floors_count"]),
        fact("building_footprint", building_record["area_sqm"], format: "area"),
        fact("building_address", building_record["address"]),
        fact("previous_identifier", building_record["old_identifier"])
      ]
    end

    def deed_identity_facts
      [
        fact("subject_area", @facts["subject_area_sqm"], format: "area"),
        fact("purpose", @facts["purpose"]),
        fact("address", @facts["address"]),
        fact("additional_parts", @facts["additional_parts"]),
        fact("previous_identifier", subject_record["old_identifier"])
      ]
    end

    def technical_reference_facts
      [
        fact("subject_area", @facts["subject_area_sqm"], format: "area"),
        fact("purpose", @facts["purpose"]),
        fact("position", position_values),
        fact("additional_parts", @facts["additional_parts"]),
        fact("address", @facts["address"])
      ]
    end

    def planning_facts
      summary = @analysis.summary.fetch("planning_summary", {}).to_h
      [
        fact("planning_area", summary["area_name"]),
        fact("predominant_floors", summary["predominant_floors"])
      ]
    end

    def registry_facts(topic_key)
      registry_kind = REGISTRY_KINDS.fetch(topic_key)
      acts_by_kind.fetch(registry_kind, []).first(2).map do |act|
        fact("matched_record", {
          "title" => act.title,
          "number" => act.act_number,
          "issued_on" => act.issued_on&.iso8601,
          "issuer" => act.issuer
        }.compact, format: "administrative_act")
      end
    end

    def facts_records
      @facts.fetch("cadastre_records", {}).to_h
    end

    def subject_record
      facts_records.fetch(@analysis.identifier_level, {}).to_h
    end

    def parcel_record
      facts_records.fetch("parcel", {}).to_h
    end

    def building_record
      facts_records.fetch("building", {}).to_h
    end

    def position_values
      {
        "entrance" => @facts["entrance"],
        "floor" => @facts["floor"],
        "object_number" => @facts["object_number"]
      }.compact_blank
    end

    def regulation_values
      {
        "regulated_plot" => parcel_record["regulation_parcel"] || @facts["upi"],
        "quarter" => parcel_record["quarter"]
      }.compact_blank
    end

    def acts_by_kind
      @acts_by_kind ||= @visible_acts.group_by(&:registry_kind)
    end

    def default_visible_acts
      scope = @analysis.administrative_acts.chronological
      scope = scope.limit(2) unless @analysis.full_report_unlocked?
      scope.to_a
    end

    def fact(key, value, format: "text")
      return if value.blank?

      { "key" => key, "value" => value, "format" => format }
    end
  end
end
