class ApplicationController < ActionController::Base
  include GuestJourneyOwnership
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :redirect_legacy_locale_query
  around_action :switch_locale

  helper_method :product_name, :legal_entity_name, :legal_entity_eik, :legal_entity_address,
    :general_contact_email, :legal_contact_email, :legal_document_version

  def default_url_options
    { locale: I18n.locale == I18n.default_locale ? nil : I18n.locale }
  end

  private

  def redirect_legacy_locale_query
    query_locale = request.query_parameters["locale"]
    return unless request.get? && query_locale.in?(I18n.available_locales.map(&:to_s)) && request.path_parameters[:locale].blank?

    route_locale = query_locale == I18n.default_locale.to_s ? nil : query_locale
    route_options = request.path_parameters.symbolize_keys.except(:format).merge(locale: route_locale, only_path: true)
    target_path = url_for(route_options)
    remaining_query = request.query_parameters.except("locale")
    target_path = "#{target_path}?#{remaining_query.to_query}" if remaining_query.present?
    redirect_to target_path, status: :moved_permanently
  end

  def switch_locale(&action)
    requested = request.path_parameters[:locale].presence || I18n.default_locale
    locale = requested.to_s.in?(I18n.available_locales.map(&:to_s)) ? requested : I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def product_name
    Rails.application.config.x.product_name
  end

  def legal_entity_name
    I18n.locale == :en ? Rails.application.config.x.legal_entity_name_en : Rails.application.config.x.legal_entity_name
  end
  def legal_entity_eik = Rails.application.config.x.legal_entity_eik
  def legal_entity_address
    I18n.locale == :en ? Rails.application.config.x.legal_entity_address_en : Rails.application.config.x.legal_entity_address
  end
  def general_contact_email = Rails.application.config.x.general_contact_email
  def legal_contact_email = Rails.application.config.x.legal_contact_email
  def legal_document_version = Rails.application.config.x.legal_document_version
end
