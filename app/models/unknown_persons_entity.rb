class UnknownPersonsEntity < Entity
  def type
    Types::NATURAL_PERSON
  end

  def name
    self[:name] || I18n.t("unknown_persons_entity.name")
  end

  # Routing helpers are used to generate links, which require the instance to be "persisted".
  def persisted?
    true
  end
end
