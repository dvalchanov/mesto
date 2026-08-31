module Analysis
  class BuyerChecklistBuilder
    def initialize(analysis:, facts:)
      @analysis = analysis
      @facts = facts
    end

    def call
      items = []
      items << item("area_missing", "needs_document") unless @facts["subject_area_sqm"]
      items << item("area_compare", "buyer_check") if @facts["subject_area_sqm"]
      items << item("location_missing", "needs_document") unless @analysis.centroid
      items.concat(registry_items)
      items << item("occupancy", "buyer_check") if @analysis.building_identifier.present?
      items << item("ownership", "not_checked")
      items << item("encumbrances", "not_checked")
      items << item("technical_inspection", "not_checked")
      items.uniq { |entry| entry["key"] }
    end

    private

    def registry_items
      kinds = @analysis.administrative_acts.distinct.pluck(:registry_kind)
      result = []
      result << item("design_visa", "review") if kinds.include?("design_visas")
      result << item("building_permit", "review") if kinds.include?("building_permits")
      result << item("planning_order", "review") if kinds.include?("urban_planning_orders")
      result
    end

    def item(key, status)
      { "key" => key, "status" => status }
    end
  end
end
