class SearchesController < ApplicationController
  def show
    @company_count = Entity.legal_entities.count

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
