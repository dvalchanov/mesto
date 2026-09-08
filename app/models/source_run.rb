class SourceRun < ApplicationRecord
  STATUSES = %w[pending running succeeded unavailable failed].freeze

  belongs_to :property_analysis
  belongs_to :analysis_revision, optional: true

  validates :source_key, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :succeeded, -> { where(status: "succeeded") }
  scope :failed_or_unavailable, -> { where(status: %w[failed unavailable]) }
end
