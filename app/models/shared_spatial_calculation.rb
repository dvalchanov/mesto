class SharedSpatialCalculation < ApplicationRecord
  validates :subject_key, :calculation_kind, :fingerprint, :geometry_basis,
    :coverage_profile_key, :calculated_at, presence: true
  validates :fingerprint, uniqueness: true
end
