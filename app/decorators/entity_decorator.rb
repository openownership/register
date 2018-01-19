class EntityDecorator < ApplicationDecorator
  delegate_all

  decorates_finders

  transliterated_attrs :name, :address, :company_type
end
