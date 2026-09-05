class AddMatchBasisToAdministrativeActReferences < ActiveRecord::Migration[8.1]
  def change
    add_column :administrative_act_references, :match_basis, :string
  end
end
