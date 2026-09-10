require "rails_helper"

RSpec.describe BulgarianEik do
  it "validates and normalizes Bulgarian EIK values" do
    expect(described_class.valid?("200 370 069")).to be(true)
    expect(described_class.normalize("ЕИК 200 370 069")).to eq("200370069")
    expect(described_class.valid?("123456789")).to be(false)
  end
end
