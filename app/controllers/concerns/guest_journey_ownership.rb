module GuestJourneyOwnership
  extend ActiveSupport::Concern

  GUEST_COOKIE = :mesto_guest_identity
  CURRENT_JOURNEY_COOKIE = :mesto_current_journey

  included do
    helper_method :current_buyer_journey, :guest_journeys
  end

  private

  def guest_identity(create: false)
    identity = cookies.signed[GUEST_COOKIE]
    return identity if identity.present? || !create

    SecureRandom.urlsafe_base64(32).tap do |value|
      cookies.signed[GUEST_COOKIE] = journey_cookie(value, httponly: true)
    end
  end

  def guest_identity_digest(create: false)
    identity = guest_identity(create:)
    Digest::SHA256.hexdigest(identity) if identity.present?
  end

  def guest_journeys
    digest = guest_identity_digest
    return BuyerJourney.none unless digest

    BuyerJourney.for_guest(digest).order(last_active_at: :desc)
  end

  def current_buyer_journey
    return @current_buyer_journey if defined?(@current_buyer_journey)

    explicit_token = params[:journey].presence
    token = explicit_token || cookies.signed[CURRENT_JOURNEY_COOKIE]
    @current_buyer_journey = if token.present? && guest_identity_digest
      BuyerJourney.for_guest(guest_identity_digest).find_by(public_token: token)
    end
    @current_buyer_journey ||= guest_journeys.first unless explicit_token
  end

  def remember_current_journey(journey)
    @current_buyer_journey = journey
    cookies.signed[CURRENT_JOURNEY_COOKIE] = journey_cookie(journey.public_token, httponly: true)
  end

  def forget_current_journey
    remove_instance_variable(:@current_buyer_journey) if defined?(@current_buyer_journey)
    cookies.delete(CURRENT_JOURNEY_COOKIE)
  end

  def journey_cookie(value, httponly:)
    {
      value:,
      expires: Rails.application.config.x.anonymous_journey_retention_days.days.from_now,
      httponly:,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end
end
