class TreeNodeDecorator < ApplicationDecorator
  delegate_all

  decorates_association :entity
  decorates_association :relationship
  decorates_association :nodes, with: TreeNodeDecorator
end
