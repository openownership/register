module EntityHelper
  def entity_name_or_tooltip(entity, position)
    if entity.is_a?(UnknownPersonsEntity)
      glossary_tooltip(content_tag(:span, "unknown", class: "unknown"), :unknown_persons, position)
    else
      entity.name
    end
  end

  def entity_link(entity, &block)
    if entity.is_a?(UnknownPersonsEntity) || entity.is_a?(CircularOwnershipEntity)
      capture(&block)
    else
      link_to(entity_path(entity), &block)
    end
  end

  def entity_jurisdiction(entity, short: false)
    return unless (country = entity.country)

    if entity.country_subdivision
      country_label = short ? country.alpha2 : country.name
      "#{entity.country_subdivision.name} (#{country_label})"
    else
      short ? country.names[0] : country.name
    end
  end

  def entity_attributes_snippet(entity)
    parts = []
    if entity.natural_person?
      parts << entity.country.try(:nationality)
      date_of_birth(entity).presence.try do |date_of_birth|
        parts << t("helpers.entities.entity_attributes_snippet.date_of_birth", date_of_birth: date_of_birth)
      end
    else
      parts << entity_jurisdiction(entity, short: true)
      parts << "(#{entity.incorporation_date} – #{entity.dissolution_date})" if entity.incorporation_date?
    end
    parts.compact.join(' ')
  end

  def date_of_birth(entity)
    return unless entity.dob
    parts = []
    parts << Date::MONTHNAMES[entity.dob.month] if entity.dob.atoms.size > 1
    parts << entity.dob.year
    parts.join(" ")
  end
end
