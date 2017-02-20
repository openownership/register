class SearchesController < ApplicationController
  def show
    return if params[:q].blank?

    query = {
      match: {
        name: {
          query: params[:q],
          operator: 'AND'
        }
      }
    }

    response = Entity.search(query: query).page(params[:page]).per(10)

    @results = response.results

    @records = response.records.to_a
  end
end
