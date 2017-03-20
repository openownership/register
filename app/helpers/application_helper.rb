module ApplicationHelper
  def asset_present?(path)
    if Rails.configuration.assets.compile
      Rails.application.precompiled_assets.include?(path)
    else
      Rails.application.assets_manifest.assets[path].present?
    end
  end

  def render_haml(haml)
    Haml::Engine.new(haml).render(self)
  end

  def glossary_tooltip(label, glossary_key, position)
    content_tag(
      :span,
      label,
      "data-toggle" => "tooltip",
      "data-placement" => position,
      title: t("glossary.#{glossary_key}"),
      class: "tooltip-helper"
    )
  end

  def google_search_uri(params)
    uri = URI('https://www.google.com/search')
    uri.query = params.to_query
    uri.to_s
  end

  def opencorporates_officers_search_uri(params)
    uri = URI('https://opencorporates.com/officers')
    uri.query = params.to_query
    uri.to_s
  end

  PARTIAL_DATE_FORMATS = {
    1 => '%04d',
    2 => '%04d-%02d',
    3 => '%04d-%02d-%02d'
  }.freeze

  def partial_date_format(iso8601_date)
    return if iso8601_date.nil?

    PARTIAL_DATE_FORMATS[iso8601_date.atoms.size] % iso8601_date.atoms
  end
end
