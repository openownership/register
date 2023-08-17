module SearchHelper
  def search_filter_type(value)
    if value == RegisterSourcesBods::StatementTypes['personStatement']
      icon_filename = 'icon-natural-person.svg'
      label = t(value, scope: :entity_types).capitalize
    else
      icon_filename = 'icon-legal-entity.svg'
      label = glossary_tooltip(t(value, scope: :entity_types)&.capitalize, value, :right)
    end

    icon = content_tag(:span, image_tag(icon_filename), class: 'filter-type-icon')

    [label, icon]
  end

  def search_filter_country(code)
    return unless code

    country = ISO3166::Country[code]

    return unless country

    [country.names.first, country_flag(country)]
  end
end
