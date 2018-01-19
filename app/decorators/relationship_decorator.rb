class RelationshipDecorator < ApplicationDecorator
  delegate_all

  decorates_finders

  decorates_association :source
  decorates_association :target
end
