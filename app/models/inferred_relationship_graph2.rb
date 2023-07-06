class InferredRelationshipGraph2
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
      entity.id == source_entity.id
    end
  end

  private

  def select_relationships(&stop_condition)
    inferred_relationships = []

    select_relationships_recursive(
      entity: @entity,
      inferred_relationships: inferred_relationships,
      stop_condition: stop_condition,
    )

    inferred_relationships
  end

  def select_relationships_recursive(
    entity:,
    inferred_relationships:,
    stop_condition:, seen_entities: [],
    seen_relationships: []
  )
    return unless entity

    immediate_relationships = entity.relationships_as_target

    if stop_condition.call(entity, immediate_relationships) \
       && !seen_relationships.empty?

      inferred_relationship = InferredRelationship2.new(
        source: entity,
        target: @entity,
        sourced_relationships: seen_relationships,
      )
      if seen_relationships.size == 1
        inferred_relationship.interests = seen_relationships.first.interests
      end
      inferred_relationships << inferred_relationship
    end

    return if seen_entities.include?(entity) # prevent infinite loops

    immediate_relationships.each do |relationship|
      select_relationships_recursive(
        entity: relationship.source,
        inferred_relationships: inferred_relationships,
        seen_entities: [entity] + seen_entities,
        seen_relationships: [relationship] + seen_relationships,
        stop_condition: stop_condition,
      )
    end
  end
end
