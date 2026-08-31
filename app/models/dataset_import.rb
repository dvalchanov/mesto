class DatasetImport < ApplicationRecord
  STATUSES = %w[running succeeded skipped failed].freeze

  belongs_to :spatial_dataset

  validates :status, inclusion: { in: STATUSES }
end
