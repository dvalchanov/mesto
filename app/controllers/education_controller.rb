class EducationController < ApplicationController
  before_action :load_catalog

  def hub
    @stages = @catalog.published("stage").sort_by { |entry| entry["position"] }
    @documents = @catalog.published("document").first(6)
    @terms = @catalog.published("term").first(6)
    record_education_event("education_hub_viewed", mode: current_buyer_journey ? "personalized" : "anonymous")
  end

  def building_overview
    @stages = @catalog.published("stage").sort_by { |entry| entry["position"] }
    @journey = current_buyer_journey
  end

  def building_stage
    @stage = find_published!("stage", params[:stage])
    @stages = @catalog.published("stage").sort_by { |entry| entry["position"] }
    @journey = current_buyer_journey
    @buyer_stage = params[:buyer_stage].presence_in(BuyerJourney::BUYER_STAGES) || @journey&.buyer_stage || "researching"
    record_education_event("stage_explored", content_key: @stage["key"], mode: @journey ? "personalized" : "anonymous")
  end

  def buying_overview
    @guides = @catalog.published("guide")
    @journey = current_buyer_journey
  end

  def documents
    @query = params[:q].to_s.first(100)
    @entries = Education::Search.new(catalog: @catalog).call(@query, kinds: @query.present? ? %w[document term] : %w[document])
    record_education_event("education_search_performed", kind: "document", results: @entries.length) if @query.present?
  end

  def document
    @entry = find_published!("document", params[:slug])
    record_education_event("document_explanation_opened", content_key: @entry["key"])
  end

  def terms
    @query = params[:q].to_s.first(100)
    @entries = Education::Search.new(catalog: @catalog).call(@query, kinds: %w[term])
    record_education_event("education_search_performed", kind: "term", results: @entries.length) if @query.present?
  end

  def term
    @entry = find_published!("term", params[:slug])
  end

  private

  def load_catalog
    @catalog = Education::Catalog.instance
  end

  def find_published!(kind, slug)
    @catalog.find_published_by_slug(kind, slug) || raise(ActionController::RoutingError, "Not Found")
  end

  def record_education_event(name, metadata = {})
    ProductEvent.record(name, metadata: metadata.compact)
  end
end
