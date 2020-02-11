class EntityDecorator < ApplicationDecorator
  delegate_all

  decorates_finders

  decorates_association :master_entity
  decorates_association :merged_entities

  transliterated_attrs :name, :address, :company_type

  alias transliterated_name name
  def name
    if object.name.blank?
      if object.natural_person?
        I18n.t 'entities.show.person_name_missing'
      else
        I18n.t 'entities.show.company_name_missing'
      end
    else
      transliterated_name
    end
  end

  def schema
    return person_schema if object.natural_person?

    organisation_schema
  end

  def person_schema
    {
      "@context" => "https://schema.org/",
      "@type" => "Person",
      "name": name,
      "address" => object.address,
      "birthDate" => h.partial_date_format(object.dob),
      "url" => Rails.application.routes.url_helpers.entity_url(object),
    }.compact.to_json
  end

  def organisation_schema
    {
      "@context" => "https://schema.org/",
      "@type" => "Organization",
      "name" => name,
      "address" => object.address,
      "foundingDate" => object.incorporation_date,
      "dissolutionDate" => object.dissolution_date,
      "url" => Rails.application.routes.url_helpers.entity_url(object),
    }.compact.to_json
  end
end
