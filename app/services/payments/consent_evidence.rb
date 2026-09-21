module Payments
  ConsentEvidence = Data.define(
    :terms_accepted_at,
    :immediate_performance_consented_at,
    :withdrawal_loss_acknowledged_at,
    :legal_document_version
  ) do
    def self.recorded(at: Time.current, version: Rails.application.config.x.legal_document_version)
      new(
        terms_accepted_at: at,
        immediate_performance_consented_at: at,
        withdrawal_loss_acknowledged_at: at,
        legal_document_version: version
      )
    end

    def complete?
      terms_accepted_at.present? && immediate_performance_consented_at.present? &&
        withdrawal_loss_acknowledged_at.present? && legal_document_version.present?
    end
  end
end
