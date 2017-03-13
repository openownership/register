class Relationship
  include Mongoid::Document

  field :interests, type: Array, default: []
  field :sample_date, type: String

  belongs_to :source, class_name: 'Entity'
  belongs_to :target, class_name: 'Entity'

  embeds_one :provenance
  embeds_many :intermediate_entities, class_name: 'Entity'
  embeds_many :intermediate_relationships, class_name: 'Relationship'

  index source_id: 1
  index target_id: 1

  def sample_date
    return nil unless self[:sample_date]
    ISO8601::Date.new(self[:sample_date])
  end
end
