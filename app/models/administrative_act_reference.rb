class AdministrativeActReference < ApplicationRecord
  belongs_to :administrative_act

  validates :cadastral_identifier, :reference_level, presence: true
  validates :cadastral_identifier, uniqueness: { scope: :administrative_act_id }
end
