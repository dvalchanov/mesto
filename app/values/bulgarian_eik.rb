class BulgarianEik
  NINE_DIGIT_WEIGHTS = [ 1, 2, 3, 4, 5, 6, 7, 8 ].freeze
  NINE_DIGIT_SECOND_WEIGHTS = [ 3, 4, 5, 6, 7, 8, 9, 10 ].freeze
  THIRTEEN_DIGIT_WEIGHTS = [ 2, 7, 3, 5 ].freeze
  THIRTEEN_DIGIT_SECOND_WEIGHTS = [ 4, 9, 5, 7 ].freeze

  def self.normalize(value)
    value.to_s.gsub(/\D/, "")
  end

  def self.valid?(value)
    digits = normalize(value)
    return valid_nine?(digits) if digits.length == 9
    return valid_thirteen?(digits) if digits.length == 13

    false
  end

  def self.valid_nine?(digits)
    return false unless digits.match?(/\A\d{9}\z/)

    expected = checksum(digits[0, 8], NINE_DIGIT_WEIGHTS, NINE_DIGIT_SECOND_WEIGHTS)
    expected == digits[-1].to_i
  end

  def self.valid_thirteen?(digits)
    return false unless digits.match?(/\A\d{13}\z/) && valid_nine?(digits.first(9))

    expected = checksum(digits[8, 4], THIRTEEN_DIGIT_WEIGHTS, THIRTEEN_DIGIT_SECOND_WEIGHTS)
    expected == digits[-1].to_i
  end

  def self.checksum(digits, weights, second_weights)
    remainder = weighted_remainder(digits, weights)
    remainder = weighted_remainder(digits, second_weights) if remainder == 10
    remainder == 10 ? 0 : remainder
  end
  private_class_method :checksum

  def self.weighted_remainder(digits, weights)
    digits.chars.zip(weights).sum { |digit, weight| digit.to_i * weight } % 11
  end
  private_class_method :weighted_remainder
end
