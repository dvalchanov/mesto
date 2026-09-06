require "rails_helper"

RSpec.describe Education::Search do
  subject(:search) { described_class.new }

  it "matches natural aliases regardless of spacing" do
    compact = search.call("акт16")
    spaced = search.call("акт 16")

    expect(compact.map { |entry| entry["key"] }).to include("document.commissioning")
    expect(spaced.map { |entry| entry["key"] }).to include("document.commissioning")
  end

  it "searches titles, summaries, aliases, and keywords" do
    expect(search.call("паркинг място").map { |entry| entry["key"] }).to include("term.garage_parking")
    expect(search.call("ипотека").map { |entry| entry["key"] }).to include("document.encumbrance_certificate")
    expect(search.call("стоп капаро").map { |entry| entry["key"] }).to include("document.reservation_agreement")
    expect(search.call("паспорт на сградата").map { |entry| entry["key"] }).to include("document.technical_passport")
  end

  it "can search buyer situations and construction stages from the guide" do
    kinds = %w[document term stage guide]

    expect(search.call("сравнявам варианти", kinds:).map { |entry| entry["key"] }).to include("guide.shortlisting")
    expect(search.call("акт 15", kinds:).map { |entry| entry["key"] }).to include("building.act15", "document.act15")
  end
end
