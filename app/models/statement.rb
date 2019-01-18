class Statement
  include Mongoid::Document

  field :_id, type: Hash

  field :type, type: String
  field :date, type: Date

  field :ended_date, type: ISO8601::Date

  belongs_to :entity

  index entity_id: 1
end
