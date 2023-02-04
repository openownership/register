class DataSourcesController < ApplicationController
  DATA_SOURCE_REPOSITORY = Rails.application.config.data_source_repository

  def index
    @data_sources = decorate DATA_SOURCE_REPOSITORY.where_overview_present
  end

  def show
    @data_source = DATA_SOURCE_REPOSITORY.find(params[:id])
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    @overview_html = markdown.render(@data_source.overview || "")
    @data_availability_html = markdown.render(@data_source.data_availability || "")

    return if @data_source.current_statistics.empty?

    @statistics = decorate(@data_source.current_statistics)
    @total = @statistics.find(&:total?)
    @footnote_indices = footnote_indices(@statistics)
  end

  private

  def footnote_indices(statistics)
    indices = {}
    index = 1
    statistics.each do |statistic|
      if statistic.footnote?
        indices[statistic.id] = index
        index += 1
      end
    end
    indices
  end
end
