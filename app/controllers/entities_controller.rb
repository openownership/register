class EntitiesController < ApplicationController
  def show
    @entity = Entity.find(params[:id])

    @source_relationships = Relationship.where(source: @entity)

    @ultimate_source_relationship_groupings = RelationshipGraph.new(@entity).ultimate_source_relationships.group_by { |r| r.source.name }.sort
  end
end
