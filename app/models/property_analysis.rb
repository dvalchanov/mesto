class PropertyAnalysis < ApplicationRecord
  STATUSES = %w[queued running ready partial failed].freeze
  COVERAGE_STATUSES = %w[complete good partial limited].freeze
  LOCATION_PRECISIONS = %w[cadastral_geometry official_record_geometry matched_address approximate unavailable].freeze

  has_many :source_runs, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :product_events, dependent: :nullify

  before_validation :assign_public_token, on: :create

  validates :public_token, :submitted_identifier, :settlement_code, :parcel_identifier, :identifier_level, presence: true
  validates :public_token, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :coverage_status, inclusion: { in: COVERAGE_STATUSES }
  validates :location_precision, inclusion: { in: LOCATION_PRECISIONS }

  scope :completed, -> { where(status: %w[ready partial]) }

  def to_param = public_token
  def ready_for_display? = status.in?(%w[ready partial failed])
  def running? = status.in?(%w[queued running])
  def sofia? = settlement_code == CadastralIdentifier::SOFIA_SETTLEMENT_CODE

  def full_report_unlocked?
    orders.paid.exists?
  end

  def meaningful_paid_content?
    return false unless status == "ready" && coverage_status == "complete" && sofia?

    summary["paid_content_available"] == true
  end

  def administrative_acts
    AdministrativeAct.joins(:administrative_act_references)
      .where(administrative_act_references: { cadastral_identifier: identifiers_for_matching })
      .distinct
  end

  def identifiers_for_matching
    [ submitted_identifier, building_identifier, parcel_identifier ].compact.uniq
  end

  def progress
    Array(summary["progress"])
  end

  def update_progress!(key, status)
    steps = Analysis::Runner::STAGES.map do |stage|
      existing = progress.find { |item| item["key"] == stage }
      { "key" => stage, "status" => stage == key ? status.to_s : existing&.fetch("status", nil) || "pending" }
    end
    update!(summary: summary.merge("progress" => steps))
  end

  private

  def assign_public_token
    self.public_token ||= SecureRandom.uuid
  end
end
