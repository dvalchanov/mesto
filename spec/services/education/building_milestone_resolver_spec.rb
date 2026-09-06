require "rails_helper"

RSpec.describe Education::BuildingMilestoneResolver do
  let(:analysis) { create(:property_analysis, status: "ready", completed_at: Time.current) }

  it "accepts a correctly scoped later milestone and reports disagreement without rewriting buyer stage" do
    act = create(:administrative_act, registry_kind: "occupancy_certificates", title: "Удостоверение за въвеждане в експлоатация")
    act.administrative_act_references.create!(cadastral_identifier: analysis.building_identifier, reference_level: "building", match_basis: "document")

    assessment = described_class.new(analysis:, reported_stage: "act14", visible_acts: [ act ]).call

    expect(assessment.milestone).to eq("commissioning")
    expect(assessment.match_quality).to eq("exact_subject")
    expect(assessment.conflict_flags).to include("later_evidence_than_reported")
  end

  it "rejects parcel-only, neighboring, infrastructure, and revoked records" do
    parcel = create(:administrative_act, registry_kind: "occupancy_certificates", external_key: "parcel")
    parcel.administrative_act_references.create!(cadastral_identifier: analysis.parcel_identifier, reference_level: "parcel", match_basis: "document")
    neighbor = create(:administrative_act, registry_kind: "occupancy_certificates", external_key: "neighbor")
    neighbor.administrative_act_references.create!(cadastral_identifier: "68134.1000.2000.2", reference_level: "building", match_basis: "document")
    infrastructure = create(:administrative_act, registry_kind: "occupancy_certificates", external_key: "power", title: "Въвеждане на трафопост")
    infrastructure.administrative_act_references.create!(cadastral_identifier: analysis.building_identifier, reference_level: "building", match_basis: "document")
    revoked = create(:administrative_act, registry_kind: "occupancy_certificates", external_key: "revoked", status: "Отменен")
    revoked.administrative_act_references.create!(cadastral_identifier: analysis.building_identifier, reference_level: "building", match_basis: "document")

    assessment = described_class.new(analysis:, visible_acts: [ parcel, neighbor, infrastructure, revoked ]).call

    expect(assessment.milestone).to be_nil
    expect(assessment.match_quality).to eq("wrong_or_broad_subject")
    expect(assessment.limitations.join(" ")).to include("не е приложен", "отменен")
  end

  it "keeps missing evidence unavailable instead of treating it as a negative fact" do
    assessment = described_class.new(analysis:, reported_stage: "act15", visible_acts: []).call

    expect(assessment.milestone).to be_nil
    expect(assessment.evidence_basis).to eq("unavailable")
    expect(assessment.limitations.first).to include("не доказва")
  end

  it "does not treat parcel-only commissioning as commissioning a selected parcel" do
    parcel_analysis = create(
      :property_analysis,
      submitted_identifier: "68134.1000.2000",
      identifier_level: "parcel",
      building_identifier: nil,
      individual_object_identifier: nil,
      status: "ready",
      completed_at: Time.current
    )
    permit = create(:administrative_act, registry_kind: "building_permits", external_key: "parcel-permit")
    permit.administrative_act_references.create!(cadastral_identifier: parcel_analysis.parcel_identifier, reference_level: "parcel", match_basis: "document")
    occupancy = create(:administrative_act, registry_kind: "occupancy_certificates", external_key: "parcel-occupancy")
    occupancy.administrative_act_references.create!(cadastral_identifier: parcel_analysis.parcel_identifier, reference_level: "parcel", match_basis: "document")

    assessment = described_class.new(analysis: parcel_analysis, visible_acts: [ permit, occupancy ]).call

    expect(assessment.milestone).to eq("authorization")
    expect(assessment.subject_scope).to eq("parcel")
    expect(assessment.limitations.join(" ")).to include("не е приложен")
  end

  it "does not treat the identifier used for a registry search as document evidence" do
    act = create(:administrative_act, registry_kind: "occupancy_certificates")
    act.administrative_act_references.create!(
      cadastral_identifier: analysis.building_identifier,
      reference_level: "building",
      match_basis: "search_query"
    )

    assessment = described_class.new(analysis:, visible_acts: [ act ]).call

    expect(assessment.milestone).to be_nil
    expect(assessment.match_quality).to eq("wrong_or_broad_subject")
  end
end
