class CreateBuyerJourneys < ActiveRecord::Migration[8.1]
  def change
    create_table :buyer_journeys do |t|
      t.uuid :public_token, null: false, default: -> { "gen_random_uuid()" }
      t.string :guest_identity_digest, null: false
      t.references :property_analysis, foreign_key: true
      t.string :label
      t.string :property_type, null: false, default: "undecided"
      t.string :buyer_stage, null: false, default: "researching"
      t.string :user_reported_building_stage
      t.string :financing_context
      t.datetime :onboarding_completed_at
      t.datetime :last_active_at, null: false
      t.timestamps
    end
    add_index :buyer_journeys, :public_token, unique: true
    add_index :buyer_journeys, [ :guest_identity_digest, :last_active_at ]

    create_table :journey_item_progresses do |t|
      t.references :buyer_journey, null: false, foreign_key: true
      t.string :item_key, null: false
      t.string :item_kind, null: false
      t.string :status, null: false, default: "not_started"
      t.datetime :marked_at
      t.integer :content_version, null: false, default: 1
      t.timestamps
    end
    add_index :journey_item_progresses,
      [ :buyer_journey_id, :item_key, :item_kind ],
      unique: true,
      name: "idx_journey_progress_unique_item"
  end
end
