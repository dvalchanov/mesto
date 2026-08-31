class ProductEvent < ApplicationRecord
  belongs_to :property_analysis, optional: true
  belongs_to :order, optional: true

  validates :name, :occurred_at, presence: true

  def self.record(name, property_analysis: nil, order: nil, metadata: {})
    create!(name:, property_analysis:, order:, metadata:, occurred_at: Time.current)
  end
end
