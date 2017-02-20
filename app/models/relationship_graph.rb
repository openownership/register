class RelationshipGraph
  def initialize(entity)
    @entity = entity
  end

  def ultimate_source_relationships
    select_relationships do |_entity, immediate_relationships|
      immediate_relationships.empty?
    end
  end

  def relationships_to(source_entity)
    select_relationships do |entity, _immediate_relationships|
      entity == source_entity
    end
  end

  private

  def select_relationships(&block)
    relationships = []

    select_relationships_recursive(@entity, relationships, [], [], block)

    relationships
  end

  def select_relationships_recursive(entity, state, entities, relationships, block)
    immediate_relationships = Relationship.all(target: entity).to_a

    if block.call(entity, immediate_relationships) && !entities.empty?
      if relationships.size == 1
        state << relationships.first
      else
        attributes = {
          source: entity,
          target: @entity,
          intermediate_entities: entities[0..-2],
          intermediate_relationships: relationships
        }

        state << Relationship.new(attributes)
      end
    end

    return if entities.include?(entity) # prevent infinite loops

    immediate_relationships.each do |relationship|
      select_relationships_recursive(relationship.source, state, [entity] + entities, [relationship] + relationships, block)
    end
  end
end
