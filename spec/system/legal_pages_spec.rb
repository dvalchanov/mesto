require "rails_helper"

RSpec.describe "Legal pages", type: :system do
  it "shows markers for indented legal lists" do
    visit legal_notice_path

    expect(page.evaluate_script(<<~JAVASCRIPT)).to eq([ "disc", "list-item" ])
      (() => {
        const list = document.querySelector(".legal-section ul")
        return [getComputedStyle(list).listStyleType, getComputedStyle(list.querySelector("li")).display]
      })()
    JAVASCRIPT

    visit data_sources_policy_path
    expect(page.evaluate_script(
      'getComputedStyle(document.querySelector(".legal-section ol")).listStyleType'
    )).to eq("decimal")
  end

  it "uses the full navigation width and readable legal typography" do
    visit legal_notice_path

    layout = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const header = document.querySelector(".site-header__inner").getBoundingClientRect()
        const legal = document.querySelector(".legal-page__grid").getBoundingClientRect()
        return {
          headerLeft: header.left,
          headerRight: header.right,
          legalLeft: legal.left,
          legalRight: legal.right,
          bodySize: getComputedStyle(document.querySelector(".legal-section p")).fontSize,
          navigationSize: getComputedStyle(document.querySelector(".legal-page__aside a")).fontSize
        }
      })()
    JAVASCRIPT

    expect(layout.fetch("legalLeft")).to be_within(1).of(layout.fetch("headerLeft"))
    expect(layout.fetch("legalRight")).to be_within(1).of(layout.fetch("headerRight"))
    expect(layout).to include("bodySize" => "16px", "navigationSize" => "13px")

    visit data_sources_policy_path
    source_sizes = page.evaluate_script(<<~JAVASCRIPT)
      (() => ({
        summary: getComputedStyle(document.querySelector(".legal-source p")).fontSize,
        details: getComputedStyle(document.querySelector(".legal-source dd")).fontSize
      }))()
    JAVASCRIPT
    expect(source_sizes).to eq("summary" => "16px", "details" => "13px")
  end
end
