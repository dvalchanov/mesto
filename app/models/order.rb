class Order < ApplicationRecord
  STATUSES = %w[pending paid failed cancelled].freeze

  belongs_to :property_analysis
  has_many :product_events, dependent: :nullify

  before_validation :assign_public_token, on: :create

  validates :public_token, :product_code, :email, :currency, :payment_provider, presence: true
  validates :public_token, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validate :catalog_price_is_authoritative

  scope :paid, -> { where(status: "paid") }

  def to_param = public_token

  private

  def assign_public_token
    self.public_token ||= SecureRandom.uuid
  end

  def catalog_price_is_authoritative
    product = Payments::ProductCatalog.fetch(product_code)
    return errors.add(:product_code, :inclusion) unless product

    errors.add(:amount_cents, :invalid) unless amount_cents == product.fetch(:amount_cents)
    errors.add(:currency, :invalid) unless currency == product.fetch(:currency)
  end
end
