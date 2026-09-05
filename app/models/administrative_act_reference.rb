class AdministrativeActReference < ApplicationRecord
  MATCH_BASES = %w[document search_query].freeze

  belongs_to :administrative_act

  validates :cadastral_identifier, :reference_level, presence: true
  validates :cadastral_identifier, uniqueness: { scope: :administrative_act_id }
  validates :match_basis, inclusion: { in: MATCH_BASES }, allow_nil: true
end
