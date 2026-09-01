require "rails_helper"

RSpec.describe "Report polling", type: :system do
  it "automatically renders progress saved after the initial page load" do
    analysis = create(:property_analysis, status: "queued")

    visit report_path(analysis)
    expect(page).to have_text(I18n.t("reports.progress.title"))

    analysis.update!(status: "failed", failed_at: Time.current)

    expect(page).to have_text(I18n.t("reports.failed.title"), wait: 7)
  end
end
