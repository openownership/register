class SearchesController < ApplicationController
  ENTITY_REPOSITORY = Rails.application.config.entity_repository
  DATA_SOURCE_REPOSITORY = Rails.application.config.data_source_repository

  def show
    @legal_entity_count = ENTITY_REPOSITORY.count_legal_entities
    @data_sources = DATA_SOURCE_REPOSITORY.all.index_by(&:slug)

    return if params[:q].blank?

    @fallback = false

    @response = ENTITY_REPOSITORY.search(query: Search.query(search_params), aggs: Search.aggregations).page(params[:page]).per(10)

    if @response.results.total.zero? # rubocop:disable Style/GuardClause
      @fallback = true
      @response = ENTITY_REPOSITORY.search(query: Search.fallback_query(search_params), aggs: Search.aggregations).page(params[:page]).per(10)
    end
  end

  protected

  def search_params
    params.permit(:q, :type, :country)
  end

  helper_method :search_params
end
