require "rails_helper"

RSpec.describe "Home page", type: :system do
  it "keeps the final call-to-action text readable" do
    visit root_path

    button = find(".home-cta .button--subtle")
    colors = page.evaluate_script(<<~JS, button)
      (() => {
        const style = getComputedStyle(arguments[0])
        return { background: style.backgroundColor, text: style.color }
      })()
    JS

    expect(colors).to eq("background" => "rgb(251, 250, 247)", "text" => "rgb(23, 63, 52)")

    button.hover
    expect(page.evaluate_script("getComputedStyle(arguments[0]).color", button)).to eq("rgb(23, 63, 52)")
  end
end
