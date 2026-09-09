require "bigdecimal"

module Calculators
  class PaymentSchedule
    ROUNDING_POLICY = "Процентните вноски се закръглят до евроцент; само един ред „остатък“ поема валидната разлика.".freeze
    ROUNDING_POLICY_EN = "Percentage-based payments are rounded to the nearest euro cent; a single remaining-balance row absorbs any valid difference.".freeze

    def initialize(property_price_cents:, events:, reservation: {})
      @property_price_cents = property_price_cents
      @events = Array(events).map(&:deep_stringify_keys)
      @reservation = reservation.to_h.deep_stringify_keys
    end

    def call
      return incomplete(copy("Въведи цена на имота.", "Enter the property price.")) unless property_price_cents
      return incomplete(copy("Избери примерен график или добави свой.", "Choose a sample schedule or create your own.")) if events.empty?

      remaining_rows = events.count { |event| event["amount_type"] == "remaining" }
      errors = []
      errors << copy("Може да има само една вноска „остатък“.", "The schedule can contain only one remaining-balance payment.") if remaining_rows > 1
      allocated_before_remaining = 0
      calculated = events.map do |event|
        amount = case event["amount_type"]
        when "fixed" then event["amount_cents"]
        when "percentage" then percentage_amount(event["percentage"])
        when "remaining" then [ property_price_cents - allocated_before_remaining, 0 ].max
        end
        errors << copy("Липсва стойност за #{event['label'].presence || 'вноска'}.", "Enter an amount for #{event['label'].presence || 'the payment'}.") if amount.nil?
        allocated_before_remaining += amount.to_i
        event.merge("total_cents" => amount)
      end

      apply_reservation_credit!(calculated, errors)
      total_allocated = calculated.sum { _1["total_cents"].to_i }
      difference = property_price_cents - total_allocated
      errors << copy("Графикът разпределя повече от цената с #{difference.abs} евроцента.", "The schedule exceeds the price by #{difference.abs} euro cents.") if difference.negative?
      warnings = []
      warnings << copy("Остават неразпределени #{difference} евроцента от цената.", "#{difference} euro cents of the price remain unallocated.") if difference.positive?
      warnings << copy("Не е изяснено дали резервационното плащане се приспада от цената.", "It is unclear whether the reservation payment is deducted from the price.") if reservation["treatment"] == "uncertain"

      calculated.each do |event|
        own_paid = event["already_paid_cents"].to_i
        credited = event.fetch("reservation_credit_cents", 0)
        event["already_paid_total_cents"] = own_paid + credited
        event["remaining_cents"] = [ event["total_cents"].to_i - event["already_paid_total_cents"], 0 ].max
      end

      {
        "complete" => errors.empty? && warnings.empty? && difference.zero?,
        "events" => calculated,
        "total_allocated_cents" => total_allocated,
        "unallocated_cents" => [ difference, 0 ].max,
        "overallocated_cents" => [ -difference, 0 ].max,
        "historical_price_paid_cents" => historical_price_paid(calculated),
        "reservation_separate_fee_cents" => reservation["treatment"] == "separate_fee" ? reservation["amount_cents"].to_i : 0,
        "errors" => errors,
        "warnings" => warnings,
        "rounding_policy" => rounding_policy
      }
    end

    private

    attr_reader :property_price_cents, :events, :reservation

    def incomplete(message)
      { "complete" => false, "events" => [], "errors" => [], "warnings" => [ message ], "total_allocated_cents" => 0,
        "unallocated_cents" => property_price_cents.to_i, "overallocated_cents" => 0, "historical_price_paid_cents" => 0,
        "reservation_separate_fee_cents" => 0, "rounding_policy" => rounding_policy }
    end

    def percentage_amount(rate)
      return if rate.blank?

      (BigDecimal(property_price_cents.to_s) * BigDecimal(rate.to_s) / 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end

    def apply_reservation_credit!(calculated, errors)
      return unless reservation["treatment"] == "credited" && reservation["amount_cents"].to_i.positive?

      target = calculated.find { _1["key"] == reservation["credit_event_key"] }
      unless target
        errors << copy("Избери вноска, към която се приспада резервационното плащане.", "Choose the payment from which the reservation amount should be deducted.")
        return
      end
      if reservation["amount_cents"].to_i > target["total_cents"].to_i
        errors << copy("Резервационният кредит е по-голям от избраната вноска.", "The reservation credit exceeds the selected payment.")
        return
      end
      target["reservation_credit_cents"] = reservation["amount_cents"].to_i
    end

    def historical_price_paid(calculated)
      paid = calculated.sum { _1["already_paid_cents"].to_i }
      paid += reservation["amount_cents"].to_i if reservation["treatment"] == "credited" && reservation["paid_before_start"]
      paid
    end

    def rounding_policy = I18n.locale == :en ? ROUNDING_POLICY_EN : ROUNDING_POLICY
    def copy(bg, en) = LocalizedCopy.call(bg, en)
  end
end
