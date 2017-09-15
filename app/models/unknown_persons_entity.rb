class UnknownPersonsEntity < Entity
  def type
    Types::NATURAL_PERSON
  end

  def name
    I18n.t("unknown_persons_entity.name")
  end
end
