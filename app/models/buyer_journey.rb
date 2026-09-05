class BuyerJourney < ApplicationRecord
  PROPERTY_TYPES = %w[new_build completed_home house land undecided].freeze
  BUYER_STAGES = %w[
    researching shortlisting before_deposit before_preliminary_contract
    preliminary_contract_signed waiting_or_payment before_notarial_transfer
    before_handover owner unknown
  ].freeze
  BUILDING_STAGES = %w[
    land_planning authorization commencement act14 installations_act15
    act15 commissioning handover unknown
  ].freeze
  FINANCING_CONTEXTS = %w[mortgage own_funds undecided].freeze
  TRANSFERABLE_TASK_KEYS = %w[task.define_needs task.financing_plan].freeze

  belongs_to :property_analysis, optional: true
  has_many :journey_item_progresses, dependent: :destroy

  before_validation :assign_public_token, on: :create
  before_validation :touch_last_active

  validates :public_token, :guest_identity_digest, :last_active_at, presence: true
  validates :public_token, uniqueness: true
  validates :property_type, inclusion: { in: PROPERTY_TYPES }
  validates :buyer_stage, inclusion: { in: BUYER_STAGES }
  validates :user_reported_building_stage, inclusion: { in: BUILDING_STAGES }, allow_nil: true
  validates :financing_context, inclusion: { in: FINANCING_CONTEXTS }, allow_nil: true
  validates :label, length: { maximum: 80 }, allow_blank: true

  scope :for_guest, ->(digest) { where(guest_identity_digest: digest) }

  def to_param = public_token

  def duplicate_for(property_analysis:)
    transaction do
      copy = self.class.create!(
        guest_identity_digest:,
        property_analysis:,
        property_type:,
        buyer_stage:,
        financing_context:,
        onboarding_completed_at:
      )
      journey_item_progresses.find_each do |progress|
        next if progress.item_kind == "task" && !progress.item_key.in?(TRANSFERABLE_TASK_KEYS)

        copy.journey_item_progresses.create!(progress.attributes.slice("item_key", "item_kind", "status", "marked_at", "content_version"))
      end
      copy
    end
  end

  private

  def assign_public_token
    self.public_token ||= SecureRandom.uuid
  end

  def touch_last_active
    self.last_active_at ||= Time.current
  end
end
