class CadastralProperty < ApplicationRecord
  IDENTIFIER_LEVELS = %w[parcel building individual_object].freeze

  validates :cadastral_identifier, :identifier_level, :source_archive_key, :source_url, presence: true
  validates :cadastral_identifier, uniqueness: true
  validates :identifier_level, inclusion: { in: IDENTIFIER_LEVELS }
end
