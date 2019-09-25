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
end
