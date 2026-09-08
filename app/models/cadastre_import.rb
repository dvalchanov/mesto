class CadastreImport < ApplicationRecord
  STATUSES = %w[running succeeded skipped failed].freeze

  validates :source_archive_key, :source_url, presence: true
  validates :status, inclusion: { in: STATUSES }

  has_one :cadastre_source_archive,
    foreign_key: :latest_successful_import_id,
    dependent: :nullify,
    inverse_of: :latest_successful_import
end
