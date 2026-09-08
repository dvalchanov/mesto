require "bigdecimal"

module Calculators
  class Mortgage
    ENGINE_VERSION = "1.0.0"

    def initialize(principal_cents:, annual_interest_rate:, term_months:, monthly_charges_cents: 0)
      @principal_cents = principal_cents
      @annual_interest_rate = decimal(annual_interest_rate)
      @term_months = term_months
      @monthly_charges_cents = monthly_charges_cents.to_i
    end

    def call
      return incomplete("Въведи размер на кредита.") if principal_cents.nil?
      return incomplete("Въведи срок на кредита.") if term_months.nil? || term_months <= 0
      return incomplete("Въведи годишна номинална лихва.") if annual_interest_rate.nil?

      regular_payment = rounded_payment_cents
      balance = principal_cents
      total_interest = 0
      rows = (1..term_months).map do |number|
        opening = balance
        interest = percent_to_cents(opening, monthly_rate * 100)
        payment = number == term_months ? opening + interest : [ regular_payment, opening + interest ].min
        principal_paid = [ payment - interest, opening ].min
        payment = principal_paid + interest
        balance = opening - principal_paid
        total_interest += interest
        {
          "number" => number, "opening_balance_cents" => opening, "interest_cents" => interest,
          "principal_cents" => principal_paid, "payment_cents" => payment, "closing_balance_cents" => balance
        }
      end

      {
        "complete" => true,
        "engine_version" => ENGINE_VERSION,
        "principal_cents" => principal_cents,
        "regular_payment_cents" => regular_payment,
        "final_payment_cents" => rows.last&.fetch("payment_cents", 0),
        "total_interest_cents" => total_interest,
        "total_principal_and_interest_cents" => principal_cents + total_interest,
        "monthly_charges_cents" => monthly_charges_cents,
        "total_regular_monthly_outflow_cents" => regular_payment + monthly_charges_cents,
        "schedule" => rows,
        "assumptions" => [
          "Кредитът е усвоен изцяло, с равни месечни периоди и постоянна номинална лихва.",
          "Вноската се закръгля до евроцент; последната се коригира, така че остатъкът по главницата да стане нула.",
          "Сметката не включва гратисен период, балонна вноска, предсрочно погасяване или специфичен начин за начисляване на дневна лихва."
        ]
      }
    end

    private

    attr_reader :principal_cents, :annual_interest_rate, :term_months, :monthly_charges_cents

    def decimal(value)
      return if value.nil? || value.to_s.empty?

      BigDecimal(value.to_s)
    end

    def monthly_rate
      annual_interest_rate / 100 / 12
    end

    def rounded_payment_cents
      return 0 if principal_cents.zero?

      raw = if monthly_rate.zero?
        BigDecimal(principal_cents.to_s) / term_months
      else
        principal = BigDecimal(principal_cents.to_s)
        principal * monthly_rate / (1 - ((1 + monthly_rate)**(-term_months)))
      end
      raw.round(0, BigDecimal::ROUND_HALF_UP).to_i
    end

    def percent_to_cents(cents, percent)
      (BigDecimal(cents.to_s) * percent / 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end

    def incomplete(message)
      {
        "complete" => false, "engine_version" => ENGINE_VERSION, "warnings" => [ message ], "schedule" => [],
        "principal_cents" => principal_cents, "monthly_charges_cents" => monthly_charges_cents
      }
    end
  end
end
