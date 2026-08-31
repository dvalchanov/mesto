class CadastralIdentifier
  SOFIA_SETTLEMENT_CODE = "68134"
  LEVELS = { 3 => :parcel, 4 => :building, 5 => :individual_object }.freeze

  attr_reader :value

  def initialize(value)
    @value = value.to_s.gsub(/\s+/, "")
  end

  def valid?
    components.length.between?(3, 5) && components.first&.match?(/\A\d{5}\z/) &&
      components.drop(1).all? { |component| component.match?(/\A\d+\z/) }
  end

  def settlement_code = component(0)
  def cadastre_area = component(1)
  def parcel_number = component(2)
  def building_number = component(3)
  def object_number = component(4)

  def parcel_identifier
    valid? ? components.first(3).join(".") : nil
  end

  def building_identifier
    valid? && components.length >= 4 ? components.first(4).join(".") : nil
  end

  def individual_object_identifier
    valid? && components.length == 5 ? value : nil
  end

  def level = valid? ? LEVELS.fetch(components.length) : :invalid
  def sofia? = valid? && settlement_code == SOFIA_SETTLEMENT_CODE
  def to_s = value

  private

  def components
    @components ||= value.split(".", -1)
  end

  def component(index)
    valid? ? components[index] : nil
  end
end
