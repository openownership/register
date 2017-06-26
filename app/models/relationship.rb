class Relationship
  include Mongoid::Document

  field :_id, type: Hash

  field :interests, type: Array, default: []
  field :sample_date, type: String

  belongs_to :source, class_name: 'Entity', inverse_of: :relationships_as_source
  belongs_to :target, class_name: 'Entity', inverse_of: :_relationships_as_target

  embeds_one :provenance

  index source_id: 1
  index target_id: 1

  def sample_date
    return nil unless self[:sample_date]
    ISO8601::Date.new(self[:sample_date])
  end
end
