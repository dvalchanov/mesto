FactoryBot.define do
  factory :property_analysis do
    submitted_identifier { "68134.1000.2000.1.5" }
    settlement_code { "68134" }
    parcel_identifier { "68134.1000.2000" }
    building_identifier { "68134.1000.2000.1" }
    individual_object_identifier { "68134.1000.2000.1.5" }
    identifier_level { "individual_object" }
    status { "queued" }
  end
end
