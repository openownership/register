# frozen_string_literal: true

class SearchesController < ApplicationController
  ENTITY_SERVICE = Rails.application.config.entity_service

  def show
    Rails.application.config.entity_service

    @legal_entity_count = ENTITY_SERVICE.count_legal_entities
    @data_sources = Rails.configuration.x.data_sources

    return if params[:q].blank?

    @fallback = false

    page = params[:page].to_i

    @response = ENTITY_SERVICE.search(search_params, page:, per_page: 10)

    if @response.count.zero? # rubocop:disable Style/GuardClause
      @fallback = true
      @response = ENTITY_SERVICE.fallback_search(search_params, page:, per_page: 10)
    end
  end

  protected

  def search_params
    params.permit(:q, :type, :country, :page)
  end

  helper_method :search_params
end
