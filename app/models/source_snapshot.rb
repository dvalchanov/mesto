class SourceSnapshot < ApplicationRecord
  STATUSES = %w[succeeded failed unavailable].freeze
  COVERAGE_STATUSES = %w[complete partial unknown].freeze

  validates :source_key, :provider, :source_url, :coverage_profile_key, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :coverage_status, inclusion: { in: COVERAGE_STATUSES }
  validates :permission_status, inclusion: { in: CadastreSourceArchive::PERMISSION_STATUSES }

  scope :for_profile, ->(profile) { where(coverage_profile_key: profile.respond_to?(:key) ? profile.key : profile) }
  scope :succeeded, -> { where(status: "succeeded") }

  def self.latest(source_key, profile: DataCoverage.profile)
    for_profile(profile).where(source_key:).order(created_at: :desc).first
  end

  def self.latest_for_identifiers(source_key, identifiers:, profile: DataCoverage.profile)
    normalized = Array(identifiers).compact.map(&:to_s).uniq.sort
    for_profile(profile)
      .where(source_key:)
      .where("metadata -> 'searched_identifiers' @> ?", normalized.to_json)
      .order(created_at: :desc)
      .first
  end
end
