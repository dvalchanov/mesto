class OrdersController < ApplicationController
  before_action :set_analysis

  def new
    return redirect_to report_path(@analysis), alert: t("checkout.already_unlocked") if @analysis.full_report_unlocked?
    return redirect_to report_path(@analysis), alert: t("checkout.unavailable") unless @analysis.meaningful_paid_content?

    @order = @analysis.orders.new(product_code: "full_property_report")
    @product = Payments::ProductCatalog.fetch("full_property_report")
  end

  def create
    return redirect_to report_path(@analysis) if @analysis.full_report_unlocked?
    return redirect_to report_path(@analysis), alert: t("checkout.unavailable") unless @analysis.meaningful_paid_content?

    @order = Payments::Gateway.configured.create_order(
      property_analysis: @analysis,
      email: params.dig(:order, :email).to_s.strip,
      product_code: "full_property_report"
    )
    redirect_to checkout_path(@order)
  rescue ActiveRecord::RecordInvalid => error
    @order = error.record
    @product = Payments::ProductCatalog.fetch("full_property_report")
    render :new, status: :unprocessable_content
  end

  private

  def set_analysis
    @analysis = PropertyAnalysis.find_by!(public_token: params[:public_token])
  end
end
