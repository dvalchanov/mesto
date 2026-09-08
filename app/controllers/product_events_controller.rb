class ProductEventsController < ApplicationController
  ALLOWED_NAMES = %w[
    contextual_explanation_opened calculator_opened calculation_completed
    explanation_opened scenario_compared calculator_to_property_check
  ].freeze

  def create
    name = params[:name].to_s
    return head :unprocessable_content unless name.in?(ALLOWED_NAMES)
    return head :too_many_requests unless RequestThrottle.allowed?("product-event/#{request.remote_ip}", limit: 60, period: 1.minute)

    metadata = params.permit(:content_key, :mode, :calculator, :section).to_h.compact_blank
    ProductEvent.record(name, metadata:)
    head :no_content
  end
end
