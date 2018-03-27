class TreeNode
  attr_accessor :entity, :relationship, :nodes

  def initialize(entity, relationship = nil, seen_ids = [])
    @entity = entity
    @relationship = relationship
    @seen_ids = seen_ids
    @nodes = build_nodes(@seen_ids)
  end

  def leaf_nodes
    return [self] if nodes.empty?
    nodes.map(&:leaf_nodes).flatten
  end

  def leaf?
    @entity.natural_person? || @entity.is_a?(CircularOwnershipEntity)
  end

  def root?
    @seen_ids.empty?
  end

  private

  def build_nodes(seen_ids)
    return [] if entity.nil?

    relationships = entity.relationships_as_target

    if relationships.any? { |relationship| seen_ids.include?(relationship.id) }
      [TreeNode.new(CircularOwnershipEntity.new(id: "#{relationship.id}-circular-ownership"), nil, seen_ids)]
    else
      RelationshipsSorter.new(relationships).call.map do |relationship|
        TreeNode.new(relationship.source, relationship, seen_ids += [relationship.id])
      end
    end
  end
end
