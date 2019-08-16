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
          source: UnknownPersonsEntity.new_for_entity(source),
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
        source: UnknownPersonsEntity.new_for_statement(statement),
        target: source,
        sample_date: statement.date.present? ? ISO8601::Date.new(statement.date.iso8601) : nil,
        ended_date: statement.ended_date,
        raw_data_provenances: statement.raw_data_provenances,
      )
    end
  end
end
