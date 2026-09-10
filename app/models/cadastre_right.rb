class CadastreRight < ApplicationRecord
  IDENTIFIER_LEVELS = CadastralProperty::IDENTIFIER_LEVELS
  HOLDER_ENTITY_TYPES = %w[company organization].freeze

  validates :cadastral_identifier, :identifier_level, :right_type, :holder_type,
    :holder_name, :holder_entity_type, :source_archive_key, :source_url,
    :record_fingerprint, presence: true
  validates :identifier_level, inclusion: { in: IDENTIFIER_LEVELS }
  validates :holder_entity_type, inclusion: { in: HOLDER_ENTITY_TYPES }
  validates :record_fingerprint, uniqueness: true
  validate :valid_company_eik

  scope :for_identifiers, ->(identifiers) { where(cadastral_identifier: Array(identifiers).compact) }

  private

  def valid_company_eik
    return unless holder_entity_type == "company"
    return if BulgarianEik.valid?(holder_identifier)

    errors.add(:holder_identifier, "must be a valid EIK for a company right holder")
  end
end
