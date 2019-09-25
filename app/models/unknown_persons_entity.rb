class UnknownPersonsEntity < Entity
  field :unknown_reason, type: String, default: 'unknown'
  field :self_updated_at, type: Time

  def self.new_for_entity(entity)
    new(
      id: "#{entity.id}#{Entity::UNKNOWN_ID_MODIFIER}",
      self_updated_at: entity.self_updated_at,
    )
  end

  def self.new_for_statement(statement)
    new(
      id: "#{statement.entity.id}-statement-#{Digest::SHA256.hexdigest(statement.id.to_json)}",
      name: I18n.t("statement-descriptions.#{statement.type}"),
      unknown_reason: statement.type,
      self_updated_at: statement.updated_at,
    )
  end

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
