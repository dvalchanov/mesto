class PropertyAnalysis < ApplicationRecord
  STATUSES = %w[queued running ready partial failed].freeze
  COVERAGE_STATUSES = %w[complete good partial limited].freeze
  LOCATION_PRECISIONS = %w[cadastral_geometry official_record_geometry matched_address approximate unavailable].freeze

  has_many :source_runs, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :product_events, dependent: :nullify

  before_validation :assign_public_token, on: :create
  after_update_commit :broadcast_terminal_report_refresh, if: :terminal_status_changed?

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

  def update_progress!(key, status, broadcast: true)
    steps = Analysis::Runner::STAGES.map do |stage|
      existing = progress.find { |item| item["key"] == stage }
      { "key" => stage, "status" => stage == key ? status.to_s : existing&.fetch("status", nil) || "pending" }
    end
    update!(summary: summary.merge("progress" => steps))
    broadcast_progress! if broadcast
  end

  def broadcast_progress!
    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        broadcast_replace_to(
          self, locale,
          target: ActionView::RecordIdentifier.dom_id(self, :progress),
          partial: "reports/progress",
          locals: { analysis: self }
        )
      end
    end
  end

  private

  def terminal_status_changed?
    saved_change_to_status? && ready_for_display?
  end

  def broadcast_terminal_report_refresh
    I18n.available_locales.each { |locale| broadcast_refresh_to(self, locale) }
  end

  def assign_public_token
    self.public_token ||= SecureRandom.uuid
  end
end
