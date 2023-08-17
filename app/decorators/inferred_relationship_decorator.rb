class InferredRelationshipDecorator < ApplicationDecorator
  delegate_all

  # decorates_association :source
  # decorates_association :target
  # decorates_association :sourced_relationships
  # decorates_association :intermediate_entities
end
