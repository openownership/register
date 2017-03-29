class TreeNode
  attr_accessor :entity, :relationship, :nodes

  def initialize(entity, relationship = nil, seen_ids = [])
    @entity = entity
    @relationship = relationship
    @nodes = build_nodes(seen_ids)
  end

  def leaf_nodes
    return [self] if nodes.empty?
    nodes.map(&:leaf_nodes).flatten
  end

  private

  def build_nodes(seen_ids)
    return [] if entity.nil?

    entity.relationships_as_target_excluding(seen_ids).map do |relationship|
      TreeNode.new(relationship.source, relationship, seen_ids.push(relationship.id))
    end
  end
end
