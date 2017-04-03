module TreeHelper
  def tree_node_classes(entity, relationship)
    arr = ["tree-node--#{entity.type}"]
    arr << 'tree-node--leaf' if entity.natural_person?
    arr << 'tree-node--root' if relationship.nil?
    arr.join(' ')
  end
end
