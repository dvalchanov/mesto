class BuyerJourneysController < ApplicationController
  before_action :load_catalog
  before_action :require_journey, only: %i[update update_progress reset destroy]

  def show
    @journey = current_buyer_journey
    @journeys = guest_journeys
    if @journey
      visible_acts = @journey.property_analysis&.administrative_acts&.includes(:administrative_act_references)&.chronological
      visible_acts = visible_acts&.limit(2) unless @journey.property_analysis&.full_report_unlocked?
      @presenter = Education::JourneyPresenter.new(journey: @journey, visible_acts:)
    end
    if @journey
      @journey.update_column(:last_active_at, Time.current)
      ProductEvent.record("journey_resumed", property_analysis: @journey.property_analysis, metadata: { mode: journey_mode(@journey) })
    end
  end

  def create
    identifier = params.dig(:buyer_journey, :cadastral_identifier).to_s.first(100).strip
    if identifier.present? && !RequestThrottle.allowed?("analysis/#{request.remote_ip}", limit: 10, period: 1.minute)
      @onboarding_error = LocalizedCopy.call("Направени са твърде много проверки. Изчакай малко и опитай отново.", "Too many checks have been submitted. Wait a moment and try again.")
      @form_values = journey_params.to_h
      return render :show, status: :too_many_requests
    end
    if identifier.present? && !CadastralIdentifier.new(identifier).valid?
      @onboarding_error = LocalizedCopy.call("Въведи валиден кадастрален идентификатор с 3 до 5 числови части.", "Enter a valid cadastral identifier with 3 to 5 numeric parts.")
      @form_values = journey_params.to_h
      return render :show, status: :unprocessable_content
    end

    @journey = BuyerJourney.new(journey_params.except(:cadastral_identifier, :property_presence))
    @journey.guest_identity_digest = guest_identity_digest(create: true)
    @journey.onboarding_completed_at = Time.current
    @journey.user_reported_building_stage = nil if @journey.user_reported_building_stage == "unknown"

    if @journey.save
      if identifier.present?
        analysis = Analysis::Starter.new(CadastralIdentifier.new(identifier)).call
        ProductEvent.record("property_attachment_started", property_analysis: analysis, metadata: { mode: "personalized_no_property" })
        @journey.update!(property_analysis: analysis)
        ProductEvent.record("property_attached", property_analysis: analysis, metadata: { mode: "property_connected" })
      end
      remember_current_journey(@journey)
      ProductEvent.record("journey_started", property_analysis: @journey.property_analysis, metadata: { mode: journey_mode(@journey) })
      redirect_to my_mesto_path, notice: LocalizedCopy.call("Планът ти е запазен в този браузър.", "Your plan has been saved in this browser.")
    else
      @onboarding_error = @journey.errors.full_messages.to_sentence
      @form_values = journey_params.to_h
      render :show, status: :unprocessable_content
    end
  end

  def update
    attributes = journey_params.except(:cadastral_identifier, :property_presence)
    attributes[:user_reported_building_stage] = nil if attributes[:user_reported_building_stage] == "unknown"
    if @journey.update(attributes.merge(last_active_at: Time.current))
      ProductEvent.record("journey_context_changed", property_analysis: @journey.property_analysis, metadata: { mode: journey_mode(@journey) })
      if params[:suggestion_action].in?(%w[accepted dismissed])
        ProductEvent.record("building_stage_suggestion_#{params[:suggestion_action]}", property_analysis: @journey.property_analysis, metadata: { mode: journey_mode(@journey) })
      end
      redirect_back fallback_location: my_mesto_path, notice: LocalizedCopy.call("Информацията в плана ти е обновена.", "Your plan has been updated.")
    else
      redirect_back fallback_location: my_mesto_path, alert: @journey.errors.full_messages.to_sentence
    end
  end

  def update_progress
    kind = params[:item_kind].to_s
    key = params[:item_key].to_s
    status = params[:status].to_s
    unless progress_item_allowed?(kind, key) && status.in?(JourneyItemProgress::STATUSES)
      return head :unprocessable_content
    end

    progress = @journey.journey_item_progresses.find_or_initialize_by(item_kind: kind, item_key: key)
    progress.update!(status:, content_version: params[:content_version].presence || 1)
    @journey.touch(:last_active_at)
    event = kind == "lesson" ? "lesson_marked_read" : "checklist_item_updated"
    ProductEvent.record(event, property_analysis: @journey.property_analysis, metadata: { status:, mode: journey_mode(@journey) })
    redirect_back fallback_location: my_mesto_path, notice: LocalizedCopy.call("Напредъкът ти е запазен.", "Your progress has been saved.")
  end

  def reset
    @journey.journey_item_progresses.delete_all
    @journey.touch(:last_active_at)
    redirect_to my_mesto_path, notice: LocalizedCopy.call("Отметките са нулирани. Избраната информация и свързаният имот са запазени.", "Your progress has been reset. Your selected details and linked property have been kept.")
  end

  def destroy
    @journey.destroy!
    next_journey = guest_journeys.first
    next_journey ? remember_current_journey(next_journey) : forget_current_journey
    redirect_to guide_path, notice: LocalizedCopy.call("Личният ти план и отбелязаният напредък са изтрити.", "Your personal plan and recorded progress have been deleted.")
  end

  def select
    journey = guest_journeys.find_by!(public_token: params[:journey])
    remember_current_journey(journey)
    redirect_to my_mesto_path
  end

  def attach_analysis
    analysis = PropertyAnalysis.find_by!(public_token: params[:public_token])
    journey = current_buyer_journey
    journey ||= BuyerJourney.create!(
      guest_identity_digest: guest_identity_digest(create: true),
      property_analysis: analysis,
      property_type: "new_build",
      buyer_stage: "unknown",
      onboarding_completed_at: Time.current
    )
    journey = journey.duplicate_for(property_analysis: analysis) if journey.property_analysis && journey.property_analysis != analysis
    journey.update!(property_analysis: analysis, last_active_at: Time.current) unless journey.property_analysis == analysis
    remember_current_journey(journey)
    ProductEvent.record("property_attached", property_analysis: analysis, metadata: { mode: "property_connected" })
    redirect_to my_mesto_path, notice: LocalizedCopy.call("Имотът е добавен, а досегашният ти напредък е запазен.", "The property has been added and your existing progress has been kept.")
  end

  private

  def load_catalog
    @catalog = Education::Catalog.instance
  end

  def require_journey
    @journey = current_buyer_journey
    head :not_found unless @journey
  end

  def journey_params
    params.fetch(:buyer_journey, {}).permit(
      :property_type, :buyer_stage, :user_reported_building_stage,
      :financing_context, :label, :property_presence, :cadastral_identifier
    )
  end

  def progress_item_allowed?(kind, key)
    return @catalog.checklist_item(key).present? if kind == "task"
    return @catalog.find(key).present? if kind == "lesson"

    false
  end

  def journey_mode(journey)
    journey.property_analysis ? "property_connected" : "personalized_no_property"
  end
end
