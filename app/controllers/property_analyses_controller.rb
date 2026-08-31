class PropertyAnalysesController < ApplicationController
  MAX_INPUT_LENGTH = 100
  REUSE_WINDOW = 24.hours

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

    analysis = reusable_analysis(identifier)
    reused = analysis.present?
    analysis ||= create_analysis(identifier)
    ProductEvent.record("search_submitted", property_analysis: analysis, metadata: { reused: })
    redirect_to report_path(analysis)
  end

  private

  def reusable_analysis(identifier)
    PropertyAnalysis.completed.where(submitted_identifier: identifier.to_s)
      .where(completed_at: REUSE_WINDOW.ago..).order(completed_at: :desc).first
  end

  def create_analysis(identifier)
    analysis = PropertyAnalysis.create!(
      submitted_identifier: identifier.to_s,
      settlement_code: identifier.settlement_code,
      parcel_identifier: identifier.parcel_identifier,
      building_identifier: identifier.building_identifier,
      individual_object_identifier: identifier.individual_object_identifier,
      identifier_level: identifier.level.to_s,
      status: "queued"
    )
    AnalyzePropertyJob.perform_later(analysis.id)
    analysis
  end
end
