require "rails_helper"

RSpec.describe Analysis::MetricsBuilder do
  subject(:builder) { described_class.new(analysis: create(:property_analysis)) }

  it "applies deterministic development-pressure thresholds" do
    expect(builder.development_pressure("available" => false)).to include("level" => "unavailable")
    expect(builder.development_pressure("available" => true, "recent_counts" => { "100" => 2, "250" => 2, "500" => 2 })).to include("level" => "high")
    expect(builder.development_pressure("available" => true, "recent_counts" => { "100" => 0, "250" => 1, "500" => 3 })).to include("level" => "medium")
    expect(builder.development_pressure("available" => true, "recent_counts" => { "100" => 0, "250" => 1, "500" => 1 })).to include("level" => "low")
  end
end
