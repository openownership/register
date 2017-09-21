class Statement
  include Mongoid::Document

  field :type, type: String
  field :date, type: Date

  belongs_to :entity
end
