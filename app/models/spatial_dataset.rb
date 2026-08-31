class SpatialDataset < ApplicationRecord
  has_many :spatial_features, dependent: :destroy
  has_many :dataset_imports, dependent: :destroy

  validates :key, :name, :provider, :source_url, presence: true
  validates :key, uniqueness: true
end
