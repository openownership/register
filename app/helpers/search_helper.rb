module SearchHelper
  def search_filter_type(value)
    icon_filename = if value == Entity::Types::NATURAL_PERSON
      'icon-person.svg'
    else
      'icon-company.svg'
    end

    icon = content_tag(:span, image_tag(icon_filename))

    [t(value, scope: :entity_types).capitalize, icon]
  end

  def search_filter_country(code)
    country = ISO3166::Country[code]

    [country.names.first, country_flag(country)]
  end
end
