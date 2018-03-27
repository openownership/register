class InferredRelationship
  include Mongoid::Document

  field :interests, type: Array, default: []

  belongs_to :source, class_name: 'Entity'
  belongs_to :target, class_name: 'Entity'

  embeds_many :sourced_relationships, class_name: 'Relationship'

  def intermediate_entities
    return [] unless sourced_relationships.any?
    sourced_relationships[1..-1].map(&:source)
  end

  def first_ended_relationship_in_chain
    return nil unless sourced_relationships.any?
    sourced_relationships.detect { |r| r.ended_date.present? } # rubocop:disable Style/CollectionMethods
  end
end
