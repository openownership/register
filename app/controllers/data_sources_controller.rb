# frozen_string_literal: true

class DataSourcesController < ApplicationController
  def index
    @data_sources = Rails.configuration.x.data_sources
  end

  def show
    @id = params[:id].to_sym
    @data_source = Rails.configuration.x.data_sources[@id]
    raise ActionController::RoutingError, 'Not Found' unless @data_source
  end
end
