FactoryBot.define do
  factory :administrative_act do
    sequence(:external_key) { |number| "act-#{number}" }
    registry_kind { "building_permits" }
    act_number { "RS-1" }
    title { "Building permit" }
    issued_on { Date.new(2024, 5, 17) }
    source_url { "https://nag.sofia.bg/example" }
  end
end
