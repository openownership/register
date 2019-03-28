module EntityHelper
  def entity_name_or_tooltip(entity, position)
    unknown_entity_tooltip(entity, position) || entity.name
  end

  def entity_link(entity, &block)
    (entity.is_a?(CircularOwnershipEntity) && capture(&block)) ||
      unknown_entity_tooltip(entity) ||
      entity.master_entity.present? && capture(&block) ||
      link_to(entity_path(entity), &block)
  end

  def unknown_entity_tooltip(entity, position = :top)
    return unless entity.is_a?(UnknownPersonsEntity)

    name = entity.id.to_s.include?('no-individual-or-entity-with-signficant-control') ? 'No person' : 'Unknown'
    tooltip(
      content_tag(:span, name, class: 'unknown'),
      entity.name || t('glossary.unknown_person'),
      position,
    )
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

  def from_denmark_cvr?(entity)
    entity.identifiers.any? { |e| e['document_id'].present? && e['document_id'] == 'Denmark CVR' }
  end

  def controlled_company_links(entity)
    entity.relationships_as_source
      .select { |relationship| relationship.ended_date.blank? }
      .sort_by { |relationship| relationship.target.name }
      .map { |relationship| link_to relationship.target.name, entity_path(relationship.target) }
  end
end
