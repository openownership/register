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
end
