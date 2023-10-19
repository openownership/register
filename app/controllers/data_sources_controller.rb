# frozen_string_literal: true

class DataSourcesController < ApplicationController
  DATA_SOURCE_REPOSITORY = Rails.application.config.data_source_repository

  def index
    @data_sources = decorate_with(
      DATA_SOURCE_REPOSITORY.where_overview_present,
      DataSourceDecorator
    )
  end

  def show
    @data_source = DATA_SOURCE_REPOSITORY.find(params[:id])
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    @overview_html = markdown.render(@data_source.overview || '')
    @data_availability_html = markdown.render(@data_source.data_availability || '')
  end
end
