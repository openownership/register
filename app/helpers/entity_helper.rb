module EntityHelper
  def entity_link(entity, &block)
    if entity.master_entity.present? || entity.unknown? #entity.is_a?(CircularOwnershipEntity)
      capture(&block)
    else
      link_to(entity_path(entity.id), &block)
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

  def controlled_company_links(entity)
    links = entity.relationships_as_source
      .reject(&:ended_date)
      # .limit(10)
      # .sort_by { |relationship| relationship.target.name }
      .map { |relationship| link_to relationship.target.name, entity_path(relationship.target.id) }
    # controlled_count = entity.relationships_as_source.where(ended_date: nil).size
    controlled_count = entity.relationships_as_source.reject(&:ended_date).size
    if controlled_count > 10
      remaining = controlled_count - 10
      links << link_to(I18n.t('searches.show.additional_owned_companies', count: remaining), entity_path(entity.id))
    end
    links
  end
end
