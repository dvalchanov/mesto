class PropertyFinderController < ApplicationController
  MIN_QUERY_LENGTH = 3
  MIN_SUGGESTION_LENGTH = 2

  def show
    @address = params[:address].to_s.squish.first(PropertyFinder::AddressSearch::MAX_QUERY_LENGTH)
    @filters = filter_params
    @building_identifier = building_identifier_param
    if @address.blank? && @building_identifier
      @address = CadastralProperty.usable.find_by(
        identifier_level: "building",
        cadastral_identifier: @building_identifier
      )&.address.to_s
    end
    return if @address.blank? && @building_identifier.blank?

    unless RequestThrottle.allowed?("property-finder/#{request.remote_ip}", limit: 30, period: 1.minute)
      @search_error = t("property_finder.rate_limited")
      return render status: :too_many_requests
    end

    if @building_identifier.blank? && @address.length < MIN_QUERY_LENGTH
      @search_error = t("property_finder.address_too_short")
      return render status: :unprocessable_content
    end

    @result = PropertyFinder::AddressSearch.new(
      query: @address,
      filters: @filters,
      page: params[:page],
      building_identifier: @building_identifier
    ).call
    @selected_building_identifier = if @building_identifier.present?
      @building_identifier
    elsif @result.building_identifiers.one?
      @result.building_identifiers.first
    end
    if @selected_building_identifier && @filters["floor"].present? && @result.properties.any?
      @position_map_payload = PropertyFinder::FloorPlan.new(
        building_identifier: @selected_building_identifier,
        properties: @result.properties
      ).call
    end
    if @filters.empty? && params[:page].blank?
      ProductEvent.record(
        "address_search_submitted",
        metadata: {
          matches: @result.total_count,
          buildings: @result.building_count,
          discovery_method: params[:locator_method].presence || "address"
        }
      )
    end
  end

  def suggestions
    query = params[:q].to_s.squish.first(PropertyFinder::AddressSearch::MAX_QUERY_LENGTH)
    return render json: { suggestions: [] } if query.length < MIN_SUGGESTION_LENGTH
    return render_rate_limit unless finder_lookup_allowed?

    suggestions = PropertyFinder::BuildingSearch.new(query:).call.map do |suggestion|
      {
        address: suggestion.address,
        building_count: suggestion.building_count,
        building_count_label: t("property_finder.locator.buildings", count: suggestion.building_count),
        building_identifier: suggestion.building_identifier
      }
    end
    render json: { suggestions: }
  end

  def buildings
    return render_rate_limit unless finder_lookup_allowed?

    result = PropertyFinder::BuildingMap.new(
      query: params[:q],
      bbox: params[:bbox],
      initial: params[:initial]
    ).call
    render json: result.geojson.merge(
      meta: { count: result.count, truncated: result.truncated, center: result.center }.compact
    )
  end

  private

  def filter_params
    params.permit(:entrance, :floor, :object_number, :area).to_h.compact_blank
  end

  def building_identifier_param
    identifier = CadastralIdentifier.new(params[:building_identifier])
    identifier.building_identifier if identifier.level == :building
  end

  def finder_lookup_allowed?
    RequestThrottle.allowed?("property-finder-lookup/#{request.remote_ip}", limit: 120, period: 1.minute)
  end

  def render_rate_limit
    render json: { error: t("property_finder.rate_limited") }, status: :too_many_requests
  end
end
