require "rails_helper"

RSpec.describe "Mesto journey", type: :system do
  before { driven_by :rack_test }
  before { PropertyAnalysis.where(submitted_identifier: "68134.1000.2000.1.5").destroy_all }

  it "searches, previews, checks out, pays, and revisits an unlocked report" do
    visit root_path
    expect(page).to have_css("h1", text: I18n.t("home.headline"))
    fill_in I18n.t("home.search.label"), with: "68134.1000.2000.1.5"
    click_button I18n.t("home.search.submit")

    analysis = PropertyAnalysis.last
    expect(page).to have_text(I18n.t("reports.progress.title"))
    DataSources::Sofiaplan::DatasetSynchronizer.new.sync
    Analysis::Runner.new(analysis).call
    visit report_path(analysis)
    expect(page).to have_text(I18n.t("reports.locked.cta"))
    expect(page).not_to have_text(I18n.t("reports.full.timeline"))

    click_link I18n.t("reports.locked.cta")
    fill_in I18n.t("checkout.email"), with: "buyer@example.com"
    click_button I18n.t("checkout.submit")
    click_button I18n.t("checkout.success_action")
    expect(page).to have_text(I18n.t("checkout.success_title"))
    click_link I18n.t("checkout.back_to_report")

    expect(page).to have_text(I18n.t("reports.full.timeline"))
    visit report_path(analysis)
    expect(page).to have_text(I18n.t("reports.full.timeline"))
  end
end
