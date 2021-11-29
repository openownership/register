class SearchesController < ApplicationController
  def show
    @legal_entity_count = Entity.legal_entities.count
    @data_sources = DataSource.all.index_by(&:slug)

    return if params[:q].blank?

    @fallback = false

    @response = Entity.search(query: Search.query(search_params), aggs: Search.aggregations).page(params[:page]).per(10)

    if @response.results.total.zero? # rubocop:disable Style/GuardClause
      @fallback = true
      @response = Entity.search(query: Search.fallback_query(search_params), aggs: Search.aggregations).page(params[:page]).per(10)
    end
  end

  protected

  def search_params
    params.permit(:q, :type, :country)
  end

  helper_method :search_params
end
