class EntityDecorator < ApplicationDecorator
  delegate_all

  decorates_finders

  transliterated_attrs :name, :address, :company_type

  alias transliterated_name name
  def name
    if object.name.blank?
      I18n.t 'entities.show.company_name_missing'
    else
      transliterated_name
    end
  end
end
