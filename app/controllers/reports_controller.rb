class ReportsController < ApplicationController
  before_action :set_analysis

  def show
    event_name = @analysis.full_report_unlocked? ? "full_report_viewed" : "report_viewed"
    record_view_event(event_name)
    @all_acts = @analysis.administrative_acts.includes(:administrative_act_references).chronological
    @preview_acts = @all_acts.limit(2)
    @acts = @analysis.full_report_unlocked? ? @all_acts : AdministrativeAct.none
    @source_runs = @analysis.source_runs.order(:created_at)
    @property_facts = Analysis::PropertyFactsBuilder.new(analysis: @analysis).call
    @buyer_checklist = Analysis::BuyerChecklistBuilder.new(analysis: @analysis, facts: @property_facts).call
    @due_diligence = Analysis::DueDiligenceBuilder.new(analysis: @analysis, facts: @property_facts).call
    @coverage = Analysis::CoverageBuilder.new(@source_runs, analysis: @analysis).call
    report_journey = current_buyer_journey
    report_journey = nil if report_journey&.property_analysis && report_journey.property_analysis != @analysis
    visible_education_acts = @analysis.full_report_unlocked? ? @all_acts : @preview_acts
    @education_presenter = Education::JourneyPresenter.new(
      journey: report_journey,
      analysis: @analysis,
      visible_acts: visible_education_acts
    )
    @report_journey = report_journey
    if @education_presenter.assessment&.conflict_flags&.include?("later_evidence_than_reported")
      ProductEvent.record("building_stage_suggestion_shown", property_analysis: @analysis, metadata: { mode: "property_connected" })
    end
  end

  def refresh
    if !RequestThrottle.allowed?("refresh/#{request.remote_ip}/#{@analysis.public_token}", limit: 3, period: 1.hour)
      redirect_to report_path(@analysis), alert: t("reports.refresh.rate_limited")
    elsif @analysis.running?
      redirect_to report_path(@analysis), notice: t("reports.refresh.already_running")
    elsif @analysis.completed_at && @analysis.completed_at > 15.minutes.ago
      redirect_to report_path(@analysis), alert: t("reports.refresh.too_soon")
    else
      @analysis.source_runs.delete_all
      @analysis.update!(status: "queued", summary: {}, metrics: {}, completed_at: nil, failed_at: nil, failure_message: nil)
      AnalyzePropertyJob.perform_later(@analysis.id)
      redirect_to report_path(@analysis), notice: t("reports.refresh.started")
    end
  end

  private

  def set_analysis
    @analysis = PropertyAnalysis.find_by!(public_token: params[:public_token])
  end

  def record_view_event(name)
    cache_key = "events/#{name}/#{@analysis.public_token}/#{request.remote_ip}"
    return if Rails.cache.exist?(cache_key)

    ProductEvent.record(name, property_analysis: @analysis)
    Rails.cache.write(cache_key, true, expires_in: 5.minutes)
  end
end
