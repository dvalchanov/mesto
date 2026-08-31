class CadastreImport < ApplicationRecord
  STATUSES = %w[running succeeded skipped failed].freeze

  validates :source_archive_key, :source_url, presence: true
  validates :status, inclusion: { in: STATUSES }
end
