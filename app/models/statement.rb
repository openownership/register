class Statement
  include Mongoid::Document

  field :type, type: String
  field :date, type: Date

  field :ended_date, type: ISO8601::Date

  belongs_to :entity
end
