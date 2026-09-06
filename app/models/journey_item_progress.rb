class JourneyItemProgress < ApplicationRecord
  KINDS = %w[lesson task].freeze
  STATUSES = %w[not_started in_progress done].freeze

  belongs_to :buyer_journey

  validates :item_key, presence: true, uniqueness: { scope: [ :buyer_journey_id, :item_kind ] }
  validates :item_kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  before_save :record_marked_at

  private

  def record_marked_at
    self.marked_at = status == "not_started" ? nil : Time.current if will_save_change_to_status?
  end
end
