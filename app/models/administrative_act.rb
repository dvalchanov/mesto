class AdministrativeAct < ApplicationRecord
  REGISTRY_KINDS = %w[building_permits design_visas urban_planning_orders occupancy_certificates].freeze

  has_many :administrative_act_references, dependent: :destroy

  validates :registry_kind, inclusion: { in: REGISTRY_KINDS }
  validates :external_key, :source_url, presence: true
  validates :external_key, uniqueness: { scope: :registry_kind }

  scope :chronological, -> { order(issued_on: :desc, created_at: :desc) }

  def stated_locality
    locality.presence || object_description.to_s[/[МM]естност\s*[:\-]?\s*["„]?([^",;”]+)/i, 1]&.strip
  end

  def stated_upi
    upi.presence || object_description.to_s[/\bУПИ\s+([^,;]+)/i, 1]&.strip
  end

  def self.near(point, metres)
    return none unless point

    where.not(geometry: nil).where(
      "ST_DWithin(administrative_acts.geometry::geography, ST_GeomFromText(?, 4326)::geography, ?)",
      point.as_text,
      metres
    )
  end
end
