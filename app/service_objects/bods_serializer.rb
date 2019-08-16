class BodsSerializer
  def initialize(relationships, mapper)
    @relationships = relationships

    @mapper = mapper
  end

  def statements
    seen = Set.new

    @relationships.reduce([]) do |acc, relationship|
      statements = statements_for(relationship, seen.dup)
      seen.merge(statements.map { |s| s[:statementID] })
      acc + statements
    end
  end

  private

  def statements_for(relationship, seen)
    [
      statement_for_target(relationship.target, seen),
      statement_for_source(relationship.source, seen),
      statement_for_relationship(relationship, seen),
    ].compact
  end

  def statement_for_target(entity, seen)
    statement_id = @mapper.statement_id(entity)

    return nil if seen.include? statement_id

    @mapper.entity_statement(entity)
  end

  def statement_for_source(entity, seen)
    return nil unless @mapper.generates_statement?(entity)

    statement_id = @mapper.statement_id(entity)

    return nil if seen.include? statement_id

    if entity.legal_entity?
      @mapper.entity_statement(entity)
    elsif entity.natural_person?
      @mapper.person_statement(entity)
    end
  end

  def statement_for_relationship(relationship, seen)
    statement_id = @mapper.statement_id(relationship)

    return if seen.include? statement_id

    @mapper.ownership_or_control_statement(relationship)
  end
end
