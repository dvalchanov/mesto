class CadastralProperty < ApplicationRecord
  IDENTIFIER_LEVELS = %w[parcel building individual_object].freeze
  ARCHIVE_OBJECT_KINDS = %w[parcels buildings individual_objects].freeze

  validates :cadastral_identifier, :identifier_level, :source_archive_key, :source_url, presence: true
  validates :cadastral_identifier, uniqueness: true
  validates :identifier_level, inclusion: { in: IDENTIFIER_LEVELS }

  def self.usable
    return all unless Rails.env.production?

    approved_keys = CadastreSourceArchive.for_profile(DataCoverage.profile)
      .where(object_kind: ARCHIVE_OBJECT_KINDS, permission_status: "approved")
      .select(:source_archive_key)
    where(source_archive_key: approved_keys)
  end

  def self.near(point, metres)
    return none unless point

    usable.where(
      "ST_DWithin(cadastral_properties.geometry::geography, ST_GeomFromText(?, 4326)::geography, ?)",
      point.as_text,
      metres
    )
  end

  def self.nearest_to(point)
    return none unless point

    usable.order(Arel.sql(sanitize_sql_array([
      "cadastral_properties.geometry <-> ST_GeomFromText(?, 4326)", point.as_text
    ])))
  end
end
