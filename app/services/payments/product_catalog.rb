module Payments
  class ProductCatalog
    PRODUCTS = {
      "full_property_report" => {
        name_key: "payments.products.full_property_report.name",
        amount_cents: 2_490,
        currency: "EUR"
      }
    }.freeze

    def self.fetch(code)
      PRODUCTS[code.to_s]
    end
  end
end
