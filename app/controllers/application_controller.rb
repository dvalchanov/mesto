class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :switch_locale

  helper_method :product_name

  private

  def switch_locale(&action)
    requested = params[:locale].presence || cookies[:locale].presence || I18n.default_locale
    locale = requested.to_s.in?(I18n.available_locales.map(&:to_s)) ? requested : I18n.default_locale
    cookies[:locale] = { value: locale, expires: 1.year.from_now } if params[:locale].present?
    I18n.with_locale(locale, &action)
  end

  def product_name
    Rails.application.config.x.product_name
  end
end
