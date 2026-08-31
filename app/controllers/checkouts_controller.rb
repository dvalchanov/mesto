class CheckoutsController < ApplicationController
  before_action :set_order
  before_action :require_fake_payments, only: %i[succeed fail cancel]

  def show
    @outcome = params[:outcome].presence_in(%w[failed cancelled])
  end

  def succeed
    Payments::Gateway.configured.succeed(@order)
    redirect_to checkout_success_path(@order)
  rescue Payments::Gateway::InvalidTransition
    redirect_to checkout_path(@order), alert: t("checkout.invalid_transition")
  end

  def fail
    Payments::Gateway.configured.fail(@order)
    redirect_to checkout_path(@order, outcome: "failed")
  rescue Payments::Gateway::InvalidTransition
    redirect_to checkout_path(@order), alert: t("checkout.invalid_transition")
  end

  def cancel
    Payments::Gateway.configured.cancel(@order)
    redirect_to checkout_path(@order, outcome: "cancelled")
  rescue Payments::Gateway::InvalidTransition
    redirect_to checkout_path(@order), alert: t("checkout.invalid_transition")
  end

  def success
    redirect_to checkout_path(@order) unless @order.status == "paid"
  end

  private

  def set_order
    @order = Order.find_by!(public_token: params[:public_token])
    @analysis = @order.property_analysis
  end

  def require_fake_payments
    return if Rails.application.config.x.fake_payments_enabled

    head :not_found
  end
end
