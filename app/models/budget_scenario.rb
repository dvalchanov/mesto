class BudgetScenario < ApplicationRecord
  INPUT_SCHEMA_VERSION = 1

  belongs_to :buyer_journey, optional: true
  belongs_to :property_analysis, optional: true

  before_validation :assign_public_token, on: :create

  validates :public_token, :guest_identity_digest, :title, :currency, :engine_version, :calculated_at, presence: true
  validates :public_token, uniqueness: true
  validates :title, length: { maximum: 80 }
  validates :currency, inclusion: { in: %w[EUR] }
  validates :input_schema_version, numericality: { only_integer: true, greater_than: 0 }
  validate :journey_and_property_are_consistent

  scope :for_guest, ->(digest) { where(guest_identity_digest: digest) }

  def to_param = public_token

  def duplicate!
    self.class.create!(attributes.except("id", "public_token", "created_at", "updated_at").merge(title: "#{title} - копие".first(80)))
  end

  def stale_rules?
    current = Calculators::PurchasePlan.new(validated_inputs).call.fetch("rule_versions", {})
    current != financial_rule_versions
  rescue Calculators::RuleCatalog::RuleNotFound
    true
  end

  private

  def assign_public_token
    self.public_token ||= SecureRandom.uuid
  end

  def journey_and_property_are_consistent
    return unless buyer_journey && property_analysis && buyer_journey.property_analysis_id.present?
    return if buyer_journey.property_analysis_id == property_analysis_id

    errors.add(:property_analysis, "не съответства на избрания личен план")
  end
end
