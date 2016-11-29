class EntitiesController < ApplicationController
  def show
    @entity = Entity.find(params[:id])
  end
end
