require "rails_helper"

RSpec.describe PropertyGraph::PrivacyFilter do
  it "removes personal identifiers and contact details recursively" do
    filtered = described_class.call(
      "name" => "Публично име",
      "egn" => "0000000000",
      "profile" => {
        "birth_date" => "1990-01-01",
        "email" => "person@example.test",
        "public_role" => "manager"
      }
    )

    expect(filtered).to eq("name" => "Публично име", "profile" => { "public_role" => "manager" })
  end
end
