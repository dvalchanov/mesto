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
  end
end
