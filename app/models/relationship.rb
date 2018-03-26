class Relationship
  include Mongoid::Document

  field :_id, type: Hash

  field :interests, type: Array, default: []
  field :sample_date, type: ISO8601::Date
  field :ended_date, type: ISO8601::Date

  belongs_to :source, class_name: 'Entity', inverse_of: :relationships_as_source
  belongs_to :target, class_name: 'Entity', inverse_of: :_relationships_as_target

  embeds_one :provenance

  index source_id: 1
  index target_id: 1

  def to_builder
    Jbuilder.new do |json|
      json.source_id source_id.to_s
      json.target_id target_id.to_s
      json.interests interests
      json.sample_date sample_date&.atoms

      json.provenance provenance.to_builder
    end
  end
end
