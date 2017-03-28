class SearchesController < ApplicationController
  def show
    @company_count = Entity.legal_entities.count

    return if params[:q].blank?

    @response = Entity.search(query: Search.query(search_params), aggs: Search.aggregations).page(params[:page]).per(10)
  end

  protected

  def search_params
    params.permit(:q, :type, :country)
  end

  helper_method :search_params
end
