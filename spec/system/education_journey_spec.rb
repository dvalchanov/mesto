require "rails_helper"

RSpec.describe "No-property education journey", type: :system do
  before { driven_by :rack_test }

  it "browses first, creates a plan, marks a task, and resumes after reload" do
    visit new_build_stage_path("akt-15")
    expect(page).to have_css("h1", text: "Подготовка за приемане и Акт 15")
    expect(page).to have_link("Въвеждане в експлоатация")

    visit my_mesto_path
    choose "Ново строителство"
    select "Преди резервация или капаро", from: "buyer_journey_buyer_stage"
    choose "Не, още проучвам"
    click_button "Създай моя план"

    expect(page).to have_text("Твоята подготовка за покупка")
    within(".checklist-list") { first(:button, "Отбележи").click }
    visit current_path
    expect(page).to have_text(/1 от \d+ задачи/)
  end
end
