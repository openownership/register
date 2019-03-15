class RelationshipsController < ApplicationController
  def show
    target_entity = Entity.find(params[:entity_id])

    source_entity = Entity.find_or_unknown(params[:id])

    CreateRelationshipsForStatements.call(source_entity)

    relationships = RelationshipGraph
      .new(target_entity)
      .relationships_to(source_entity)
    relationships = RelationshipsSorter.new(relationships)
      .call
      .uniq { |r| r.sourced_relationships.first.keys_for_uniq_grouping }

    raise Mongoid::Errors::DocumentNotFound.new(Relationship, [target_entity.id, source_entity.id]) if relationships.empty?

    reference_number = 0

    relationships.each do |relationship|
      relationship.sourced_relationships.each do |sourced_relationship|
        sourced_relationship[:reference_number] = (reference_number += 1)
      end
    end

    @target_entity = decorate(target_entity)
    @source_entity = decorate(source_entity)
    @relationships = decorate_with(relationships, InferredRelationshipDecorator)
  end
end
