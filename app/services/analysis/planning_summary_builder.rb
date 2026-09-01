module Analysis
  class PlanningSummaryBuilder
    def initialize(planning_layers)
      @planning_layers = Array(planning_layers)
    end

    def call
      properties = @planning_layers.flat_map do |layer|
        Array(layer["features"]).map { |feature| normalize(feature.fetch("properties", {})) }
      end
      {
        "available" => properties.any?,
        "area_name" => first_value(properties, "regname"),
        "district" => first_value(properties, "rajon"),
        "predominant_floors" => first_value(properties, "preobl_et"),
        "average_floors" => first_value(properties, "sr_etaj"),
        "source_keys" => @planning_layers.filter_map { |layer| layer["source_key"] }.uniq
      }.compact
    end

    private

    def normalize(properties)
      properties.to_h.transform_keys { |key| key.to_s.downcase }
    end

    def first_value(properties, key)
      properties.filter_map { |entry| entry[key].presence }.first
    end
  end
end
