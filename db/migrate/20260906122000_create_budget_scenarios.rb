class CreateBudgetScenarios < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_scenarios do |t|
      t.uuid :public_token, null: false, default: -> { "gen_random_uuid()" }
      t.string :guest_identity_digest, null: false
      t.references :buyer_journey, foreign_key: true
      t.references :property_analysis, foreign_key: true
      t.string :title, null: false, default: "Моята сметка"
      t.string :currency, null: false, default: "EUR"
      t.integer :input_schema_version, null: false, default: 1
      t.jsonb :validated_inputs, null: false, default: {}
      t.jsonb :calculation_snapshot, null: false, default: {}
      t.string :engine_version, null: false
      t.jsonb :financial_rule_versions, null: false, default: {}
      t.datetime :calculated_at, null: false
      t.timestamps
    end

    add_index :budget_scenarios, :public_token, unique: true
    add_index :budget_scenarios, [ :guest_identity_digest, :updated_at ]
  end
end
