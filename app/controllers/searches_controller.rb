class SearchesController < ApplicationController
  def show
    return if params[:q].blank?

    query = {
      match: {
        name: params[:q]
      }
    }

    response = Entity.search(query: query).page(params[:page]).per(30)

    @results = response.results
  end
end
