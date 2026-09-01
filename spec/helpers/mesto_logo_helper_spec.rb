require "rails_helper"

RSpec.describe MestoLogoHelper, type: :helper do
  def logo_fragment(**options)
    Nokogiri::HTML.fragment(helper.mesto_wordmark(**options))
  end

  it "builds a readable five-row MESTO wordmark from equal square cells" do
    fragment = logo_fragment(variant: :monochrome)
    logo = fragment.at_css("svg")
    cells = fragment.css("rect")

    expect(logo["data-logo"]).to eq("mesto")
    expect(logo["data-rows"]).to eq("5")
    expect(cells.size).to eq(61)
    expect(cells.map { |cell| cell["data-letter"] }.uniq).to eq(%w[M E S T O])
    expect(cells.map { |cell| cell["y"] }.uniq.size).to eq(5)
    expect(cells).to all(satisfy { |cell| cell["width"] == cell["height"] })
  end

  it "provides monochrome, single-accent, and restrained campaign variants" do
    monochrome = logo_fragment(variant: :monochrome)
    accent = logo_fragment(variant: :accent)
    campaign = logo_fragment(variant: :campaign)

    expect(monochrome.css('[data-tone="primary"]').size).to eq(61)
    expect(accent.css('[data-tone="accent"]').size).to eq(1)
    expect(accent.at_css('[data-cell="M:2:2"]')["data-tone"]).to eq("accent")
    expect(campaign.css('[data-tone="accent"], [data-tone="secondary"], [data-tone="tertiary"]').size).to eq(4)
    expect(campaign.at_css('[data-cell="M:2:2"]')["data-tone"]).to eq("accent")
  end

  it "supports addressable custom highlights and optional intro animation" do
    fragment = logo_fragment(
      variant: :monochrome,
      animate: true,
      highlighted_cells: { "M:1:1" => :secondary, "O:2:4" => :accent }
    )

    expect(fragment.at_css("svg")["class"]).to include("mesto-wordmark--animated")
    expect(fragment.at_css('[data-cell="M:1:1"]')["data-tone"]).to eq("secondary")
    expect(fragment.at_css('[data-cell="O:2:4"]')["data-tone"]).to eq("accent")
  end

  it "includes an accessible title and rejects unsupported themes or tones" do
    fragment = logo_fragment(title: "Mesto modular wordmark")

    expect(fragment.at_css("title").text).to eq("Mesto modular wordmark")
    expect(fragment.at_css("svg")["aria-labelledby"]).to be_present
    expect { logo_fragment(theme: :neon) }.to raise_error(ArgumentError, /theme/)
    expect { logo_fragment(highlighted_cells: { "O:2:4" => :rainbow }) }.to raise_error(ArgumentError, /tone/)
  end
end
