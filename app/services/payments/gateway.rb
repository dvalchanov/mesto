module Payments
  class Gateway
    class InvalidTransition < StandardError; end

    def self.configured
      raise "Unsupported payment provider" unless Rails.application.config.x.payment_provider == "fake"

      FakeGateway.new
    end

    def create_order(property_analysis:, email:, product_code:)
      raise NotImplementedError
    end
  end
end
