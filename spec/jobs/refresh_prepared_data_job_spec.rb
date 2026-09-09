require "rails_helper"

RSpec.describe RefreshPreparedDataJob do
  it "does not refresh a cadastral source checked within the last week" do
    expect(described_class::REFRESH_INTERVAL).to eq(1.week)
    expect(described_class.new.send(:refresh_due?, 6.days.ago)).to be(false)
    expect(described_class.new.send(:refresh_due?, 8.days.ago)).to be(true)
  end
end
