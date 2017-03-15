class RelationshipsController < ApplicationController
  def show
    @target_entity = Entity.find(params[:entity_id])

    @source_entity = Entity.find(params[:id])

    @relationships = RelationshipGraph.new(@target_entity).relationships_to(@source_entity)

    raise Mongoid::Errors::DocumentNotFound.new(Relationship, [@target_entity.id, @source_entity.id]) if @relationships.empty?

    reference_number = 0

    @relationships.each do |relationship|
      relationship.intermediate_relationships.each do |intermediate_relationship|
        intermediate_relationship[:reference_number] = (reference_number += 1)
      end
    end
  end
end
