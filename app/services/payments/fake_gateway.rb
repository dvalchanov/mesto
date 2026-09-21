module Payments
  class FakeGateway < Gateway
    def create_order(property_analysis:, email:, product_code: "full_property_report", consent_evidence: nil)
      product = ProductCatalog.fetch(product_code)
      raise ArgumentError, "Unknown product" unless product
      consent_evidence ||= ConsentEvidence.recorded if Rails.env.test?
      raise ArgumentError, "Complete checkout consent evidence is required" unless consent_evidence&.complete?

      order = property_analysis.orders.create!(
        product_code:, email:, amount_cents: product.fetch(:amount_cents),
        currency: product.fetch(:currency), status: "pending", payment_provider: "fake",
        provider_reference: "fake_#{SecureRandom.uuid}",
        terms_accepted_at: consent_evidence.terms_accepted_at,
        immediate_performance_consented_at: consent_evidence.immediate_performance_consented_at,
        withdrawal_loss_acknowledged_at: consent_evidence.withdrawal_loss_acknowledged_at,
        legal_document_version: consent_evidence.legal_document_version
      )
      ProductEvent.record("checkout_started", property_analysis:, order:)
      order
    end

    def succeed(order)
      transition(order, from: %w[pending paid], to: "paid", timestamp: :paid_at, event: "fake_payment_succeeded")
    end

    def fail(order)
      transition(order, from: %w[pending failed], to: "failed", timestamp: :failed_at, event: "fake_payment_failed")
    end

    def cancel(order)
      transition(order, from: %w[pending cancelled], to: "cancelled", timestamp: :cancelled_at, event: "fake_payment_cancelled")
    end

    private

    def transition(order, from:, to:, timestamp:, event:)
      order.with_lock do
        order.reload
        return order if order.status == to
        raise InvalidTransition, "Cannot transition #{order.status} to #{to}" unless from.include?(order.status)

        order.update!(status: to, timestamp => Time.current)
        ProductEvent.record(event, property_analysis: order.property_analysis, order:)
      end
      order
    end
  end
end
