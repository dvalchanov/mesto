require "rails_helper"

RSpec.describe "Report broadcasts", type: :request do
  let(:analysis) { create(:property_analysis, status: "queued") }
  let(:stream) { Turbo::StreamsChannel.send(:stream_name_from, [ analysis, I18n.locale ]) }

  it "subscribes to updates without installing a polling controller" do
    get report_path(analysis)

    expect(response.body).to include("turbo-cable-stream-source")
    expect(response.body).not_to include('data-controller="poll"')
  end

  it "broadcasts lightweight progress replacements" do
    target = ActionView::RecordIdentifier.dom_id(analysis, :progress)

    expect {
      analysis.update_progress!("location", "active")
    }.to have_broadcasted_to(stream).with(
      a_string_including('action="replace"', %(target="#{target}"))
    )
  end

  it "broadcasts one page refresh when the report reaches a terminal state" do
    expect {
      analysis.update!(status: "failed", failed_at: Time.current)
    }.to have_broadcasted_to(stream).with(a_string_including('action="refresh"'))
  end
end
