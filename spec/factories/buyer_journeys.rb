FactoryBot.define do
  factory :buyer_journey do
    guest_identity_digest { Digest::SHA256.hexdigest(SecureRandom.urlsafe_base64(32)) }
    property_type { "new_build" }
    buyer_stage { "researching" }
    last_active_at { Time.current }
    onboarding_completed_at { Time.current }
  end

  factory :journey_item_progress do
    buyer_journey
    item_key { "task.define_needs" }
    item_kind { "task" }
    status { "not_started" }
    content_version { 1 }
  end
end
