require "rails_helper"

RSpec.describe "Locked report upsell", type: :system do
  it "keeps its dark panel treatment at desktop and mobile widths" do
    analysis = create(
      :property_analysis,
      status: "ready",
      coverage_status: "complete",
      summary: { "paid_content_available" => true }
    )

    visit report_path(analysis)

    expect(page).to have_text(I18n.t("reports.locked.cta"))
    expect(panel_background).to eq("rgb(23, 63, 52)")

    page.current_window.resize_to(390, 844)
    expect(panel_background).to eq("rgb(23, 63, 52)")
  end

  def panel_background
    page.evaluate_script("getComputedStyle(document.querySelector('.locked-panel')).backgroundColor")
  end
end
