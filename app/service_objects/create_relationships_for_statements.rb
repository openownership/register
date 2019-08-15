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
        sample_date: statement.date.present? ? ISO8601::Date.new(statement.date.iso8601) : nil,
        ended_date: statement.ended_date,
        raw_data_provenances: statement.raw_data_provenances,
      )
    end
  end
end
