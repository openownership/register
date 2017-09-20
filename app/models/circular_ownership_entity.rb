class CircularOwnershipEntity < Entity
  def type
    "circular-ownership"
  end

  def name
    I18n.t("circular_ownership_entity.name")
  end

  def relationships_as_target
    []
  end
end
