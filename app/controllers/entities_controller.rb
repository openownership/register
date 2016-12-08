class EntitiesController < ApplicationController
  def show
    @entity = Entity.find(params[:id])

    @source_relationships = Relationship.where(source: @entity)

    @target_relationships = Relationship.where(target: @entity)
  end
end
