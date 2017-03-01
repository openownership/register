module EntityHelper
  def entity_jurisdiction(entity, short: false)
    return unless (country = entity.country)

    if entity.country_subdivision
      country_label = short ? country.alpha2 : country.name
      "#{entity.country_subdivision.name} (#{country_label})"
    else
      short ? country.names[0] : country.name
    end
  end

  def entity_country_flag(entity)
    return unless (country = entity.country)

    basename = "#{country.alpha2.upcase}.svg"

    return unless asset_present?(basename)

    image_tag(basename, size: '32x16', alt: country.name, class: 'flag')
  end

  def entity_attributes_snippet(entity)
    parts = []
    if entity.natural_person?
      parts << entity.country.try(:nationality)
      date_of_birth(entity).presence.try do |date_of_birth|
        parts << "(Born #{date_of_birth})"
      end
    else
      parts << entity_jurisdiction(entity, short: true)
      parts << "(#{entity.incorporation_date} – #{entity.dissolution_date})" if entity.incorporation_date?
    end
    parts.compact.join(' ')
  end

  def date_of_birth(entity)
    parts = []
    parts << entity.dob_day if entity.dob_month?
    parts << Date::MONTHNAMES[entity.dob_month] if entity.dob_month? && (entity.dob_day? || entity.dob_year?)
    parts << entity.dob_year
    parts.compact.join(" ")
  end
end
