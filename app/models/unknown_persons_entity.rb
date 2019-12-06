class UnknownPersonsEntity < Entity
  field :unknown_reason_code, type: String, default: 'unknown'
  field :unknown_reason, type: String
  field :self_updated_at, type: Time

  def self.new_for_entity(entity)
    new(
      id: "#{entity.id}#{Entity::UNKNOWN_ID_MODIFIER}",
      self_updated_at: entity.self_updated_at,
      unknown_reason_code: 'unknown',
      unknown_reason: I18n.t("unknown_persons_entity.reasons.totally_unknown"),
    )
  end

  def self.new_for_statement(statement)
    new(
      id: "#{statement.entity.id}-statement-#{Digest::SHA256.hexdigest(statement.id.to_json)}",
      unknown_reason_code: statement.type,
      unknown_reason: I18n.t("statement-descriptions.#{statement.type}"),
      self_updated_at: statement.updated_at,
    )
  end

  def type
    Types::NATURAL_PERSON
  end

  def name
    return self[:name] if self[:name].present?

    if unknown_reason_code == 'no-individual-or-entity-with-signficant-control'
      I18n.t("unknown_persons_entity.names.no_person")
    else
      I18n.t("unknown_persons_entity.names.unknown")
    end
  end

  # Routing helpers are used to generate links, which require the instance to be "persisted".
  def persisted?
    true
  end
end
