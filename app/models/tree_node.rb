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
    @entity.natural_person?
  end

  def root?
    @seen_ids.empty?
  end

  private

  def build_nodes(seen_ids)
    return [] if entity.nil?

    entity.relationships_as_target_excluding(seen_ids).map do |relationship|
      TreeNode.new(relationship.source, relationship, seen_ids += [relationship.id])
    end
  end
end
