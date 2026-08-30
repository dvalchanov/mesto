require "rails_helper"

RSpec.describe "Home page", type: :system do
  it "identifies the application" do
    visit root_path

    expect(page).to have_css("h1", text: "PropertyLens")
    expect(page).to have_text("Bulgarian property intelligence")
  end
end
