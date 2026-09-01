class SpatialFeature < ApplicationRecord
  belongs_to :spatial_dataset

  validates :external_key, :category, :geometry, presence: true
  validates :external_key, uniqueness: { scope: :spatial_dataset_id }

  scope :in_category, ->(category) { where(category:) }

  def self.within(point, metres)
    return none unless point

    where("ST_DWithin(spatial_features.geometry::geography, ST_GeomFromText(?, 4326)::geography, ?)", point.as_text, metres)
  end

  def self.intersecting(geometry)
    return none unless geometry

    where("ST_Intersects(spatial_features.geometry, ST_GeomFromText(?, 4326))", geometry.as_text)
  end

  def self.nearest_to(point)
    return none unless point

    order(Arel.sql(sanitize_sql_array([
      "spatial_features.geometry <-> ST_GeomFromText(?, 4326)", point.as_text
    ])))
  end

  def self.with_distance_to(point)
    return none unless point

    select(Arel.sql(sanitize_sql_array([
      "spatial_features.*, ST_Distance(spatial_features.geometry::geography, " \
        "ST_GeomFromText(?, 4326)::geography) AS map_distance_m",
      point.as_text
    ])))
  end

  def distance_to(point)
    self.class.where(id:).pick(Arel.sql(self.class.sanitize_sql_array([
      "ST_Distance(spatial_features.geometry::geography, ST_GeomFromText(?, 4326)::geography)", point.as_text
    ])))
  end
end
