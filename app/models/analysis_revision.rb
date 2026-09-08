class AnalysisRevision < ApplicationRecord
  STATUSES = %w[running ready partial failed].freeze

  belongs_to :property_analysis
  has_many :source_runs, dependent: :nullify

  validates :number, :coverage_profile_key, presence: true
  validates :number, uniqueness: { scope: :property_analysis_id }
  validates :status, inclusion: { in: STATUSES }
end
