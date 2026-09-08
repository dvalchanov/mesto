class CadastreSourceArchive < ApplicationRecord
  OBJECT_KINDS = %w[parcels buildings individual_objects].freeze
  STATUSES = %w[configured checking ready stale failed].freeze
  PERMISSION_STATUSES = %w[review_required approved restricted prohibited].freeze

  belongs_to :latest_successful_import, class_name: "CadastreImport", optional: true

  validates :source_archive_key, :district, :object_kind, :source_url, :coverage_profile_key, presence: true
  validates :source_archive_key, uniqueness: { scope: :coverage_profile_key }
  validates :object_kind, inclusion: { in: OBJECT_KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :permission_status, inclusion: { in: PERMISSION_STATUSES }

  scope :enabled, -> { where(enabled: true) }
  scope :for_profile, ->(profile) { where(coverage_profile_key: profile.respond_to?(:key) ? profile.key : profile) }
end
