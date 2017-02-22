class SearchesController < ApplicationController
  def show
    @company_count = (0.45 * Entity.search(size: 0).total_count).to_i
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
