class PropertyAnalysesController < ApplicationController
  MAX_INPUT_LENGTH = 100
  def create
    raw_identifier = params[:cadastral_identifier].to_s.first(MAX_INPUT_LENGTH)
    unless RequestThrottle.allowed?("analysis/#{request.remote_ip}", limit: 10, period: 1.minute)
      @identifier_value = raw_identifier
      @identifier_error = t("home.search.rate_limited")
      return render "home/show", status: :too_many_requests
    end

    identifier = CadastralIdentifier.new(raw_identifier)
    unless identifier.valid?
      @identifier_value = raw_identifier
      @identifier_error = t("home.search.invalid")
      return render "home/show", status: :unprocessable_content
    end

    existing = PropertyAnalysis.completed.where(submitted_identifier: identifier.to_s)
      .where(completed_at: 24.hours.ago..).exists?
    analysis = Analysis::Starter.new(identifier).call
    reused = existing
    ProductEvent.record("search_submitted", property_analysis: analysis, metadata: { reused: })
    if params[:attach_to_journey] == "1"
      ProductEvent.record("property_attachment_started", property_analysis: analysis, metadata: { mode: "personalized_no_property" })
      attach_to_current_journey(analysis)
    end
    redirect_to report_path(analysis)
  end

  private

  def attach_to_current_journey(analysis)
    journey = current_buyer_journey
    return unless journey

    journey = journey.duplicate_for(property_analysis: analysis) if journey.property_analysis && journey.property_analysis != analysis
    journey.update!(property_analysis: analysis, last_active_at: Time.current) unless journey.property_analysis == analysis
    remember_current_journey(journey)
    ProductEvent.record("property_attached", property_analysis: analysis, metadata: { mode: "property_connected" })
  end
end
