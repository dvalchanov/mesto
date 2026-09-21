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

  def self.usable
    return all unless Rails.env.production?

    approved_keys = CadastreSourceArchive.for_profile(DataCoverage.profile)
      .where(object_kind: %w[parcel_rights building_rights individual_object_rights], permission_status: "approved")
      .select(:source_archive_key)
    where(source_archive_key: approved_keys)
  end

  private

  def valid_company_eik
    return unless holder_entity_type == "company"
    return if BulgarianEik.valid?(holder_identifier)

    errors.add(:holder_identifier, "must be a valid EIK for a company right holder")
  end
end
