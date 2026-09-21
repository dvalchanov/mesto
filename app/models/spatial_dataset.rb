class SpatialDataset < ApplicationRecord
  COVERAGE_STATUSES = %w[complete partial unknown].freeze

  has_many :spatial_features, dependent: :destroy
  has_many :dataset_imports, dependent: :destroy

  validates :key, :name, :provider, :source_url, presence: true
  validates :key, uniqueness: true
  validates :coverage_status, inclusion: { in: COVERAGE_STATUSES }

  scope :prepared, -> { where.not(last_imported_at: nil) }

  def self.usable
    relation = prepared
    Rails.env.production? ? relation.where(permission_status: "approved") : relation
  end

  def revision_key
    source_revision.presence || source_checksum.presence || last_imported_at&.iso8601
  end
end
