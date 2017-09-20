module TreeHelper
  def tree_node_classes(node)
    arr = ["tree-node--#{node.entity.type}"]
    arr << 'tree-node--leaf' if node.leaf?
    arr << 'tree-node--root' if node.root?
    arr.join(' ')
  end
end
