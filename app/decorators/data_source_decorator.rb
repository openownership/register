class DataSourceDecorator < ApplicationDecorator
  delegate_all

  def short_overview
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    first_para = object.overview.split(/\n{2,}/).first
    markdown.render(first_para || "")
  end
end
