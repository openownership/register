class CreateRelationshipsForStatements
  def self.call(source)
    if source.statements.any?
      when_statements(source)
    else
      [
        Relationship.new(
          id: {
            'document_id' => 'OpenOwnership Register',
            'identifier' => "#{source.id}#{Entity::UNKNOWN_ID_MODIFIER}-relationship",
          },
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
        id: {
          'document_id' => 'OpenOwnership Register',
          'statement_id' => statement.id,
        },
        source: UnknownPersonsEntity.new(
          id: "statement-descriptions-#{statement.type}",
          name: I18n.t("statement-descriptions.#{statement.type}"),
        ),
        target: source,
        ended_date: statement.ended_date,
      )
    end
  end
end
