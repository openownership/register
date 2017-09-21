class CreateRelationshipsForStatements
  def self.call(source)
    if source.statements.any?
      when_statements(source)
    else
      [
        Relationship.new(
          source: UnknownPersonsEntity.new(
            id: "#{source.id}#{Entity::UNKNOWN_ID_MODIFIER}",
          ),
          target: source,
        ),
      ]
    end
  end

  def self.when_statements(source)
    source.statements.map do |statement|
      Relationship.new(
        source: UnknownPersonsEntity.new(
          id: "statement-descriptions-#{statement.type}",
          name: I18n.t("statement-descriptions.#{statement.type}"),
        ),
        target: source,
      )
    end
  end
end
