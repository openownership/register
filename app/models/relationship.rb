class Relationship
  include Mongoid::Document

  field :interests, type: Array

  belongs_to :source, class_name: 'Entity'
  belongs_to :target, class_name: 'Entity'

  embeds_many :intermediate_entities, class_name: 'Entity'
  embeds_many :intermediate_relationships, class_name: 'Relationship'
end
