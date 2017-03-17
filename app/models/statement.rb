class Statement
  include Mongoid::Document

  field :type, type: String
  field :date, type: Date

  belongs_to :entity

  def states_no_psc?
    type == 'no-individual-or-entity-with-signficant-control'.freeze
  end
end
