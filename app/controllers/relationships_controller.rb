class RelationshipsController < ApplicationController
  def show
    @target_entity = Entity.find(params[:entity_id])

    @source_entity = Entity.find(params[:id])

    @relationships = RelationshipGraph.new(@target_entity).relationships_to(@source_entity)

    raise Mongoid::Errors::DocumentNotFound.new(Relationship, [@target_entity.id, @source_entity.id]) if @relationships.empty?
  end
end
