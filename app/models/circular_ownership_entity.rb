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

  # Routing helpers are used to generate links, which require the instance to be "persisted".
  def persisted?
    true
  end
end
