require "rails_helper"

RSpec.describe Analysis::PlanningSummaryBuilder do
  it "keeps only planning fields with a clear buyer-facing meaning" do
    summary = described_class.new([
      {
        "source_key" => "arcgis_functional_zoning",
        "features" => [
          {
            "properties" => {
              "Rajon" => "Студентска", "RegName" => "Малинова долина",
              "Preobl_et" => "от 4 до 6 етажа", "Sr_etaj" => 3.91,
              "Gaz_17" => 123, "Adm_rzp" => 456
            }
          }
        ]
      }
    ]).call

    expect(summary).to include(
      "available" => true,
      "area_name" => "Малинова долина",
      "district" => "Студентска",
      "predominant_floors" => "от 4 до 6 етажа",
      "average_floors" => 3.91
    )
    expect(summary.to_json).not_to include("Gaz", "Adm")
  end
end
