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
end
