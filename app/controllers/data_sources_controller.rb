class DataSourcesController < ApplicationController
  def show
    @data_source = DataSource.find(params[:id])
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
