require "rails_helper"

RSpec.describe Payments::FakeGateway do
  subject(:gateway) { described_class.new }

  let(:analysis) { create(:property_analysis, status: "partial", summary: { "paid_content_available" => true }) }

  it "uses the server-side catalog price and unlocks access idempotently" do
    order = gateway.create_order(property_analysis: analysis, email: "buyer@example.com")

    expect(order.amount_cents).to eq(2_490)
    expect(order.currency).to eq("EUR")
    expect { 2.times { gateway.succeed(order) } }.to change { ProductEvent.where(name: "fake_payment_succeeded").count }.by(1)
    expect(order.reload.status).to eq("paid")
    expect(analysis.reload).to be_full_report_unlocked
  end

  it "keeps access locked after failure or cancellation" do
    failed = gateway.create_order(property_analysis: analysis, email: "one@example.com")
    cancelled = gateway.create_order(property_analysis: analysis, email: "two@example.com")

    gateway.fail(failed)
    gateway.cancel(cancelled)

    expect(failed.reload.status).to eq("failed")
    expect(cancelled.reload.status).to eq("cancelled")
    expect(analysis.reload).not_to be_full_report_unlocked
  end

  it "rejects invalid transitions" do
    order = gateway.create_order(property_analysis: analysis, email: "buyer@example.com")
    gateway.fail(order)

    expect { gateway.succeed(order) }.to raise_error(Payments::Gateway::InvalidTransition)
  end
end
