class AddLegalConsentToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :terms_accepted_at, :datetime
    add_column :orders, :immediate_performance_consented_at, :datetime
    add_column :orders, :withdrawal_loss_acknowledged_at, :datetime
    add_column :orders, :legal_document_version, :string
  end
end
