class EntityGraphDecorator < ApplicationDecorator
  delegate_all

  decorates_association :entity

  def cytoscape_data
    {
      elements: { nodes: cytoscape_nodes, edges: cytoscape_edges }.to_json,
      selected: entity.id.to_s,
    }
  end

  private

  def cytoscape_nodes
    object.nodes.map { |node| cytoscape_node(node) }
  end

  def cytoscape_edges
    object.edges.map { |edge| cytoscape_edge(edge) }
  end

  def cytoscape_node(node)
    case node
    when EntityGraph::LabelNode
      cytoscape_label_node(node)
    when EntityGraph::Node
      cytoscape_entity_node(node)
    end
  end

  def cytoscape_edge(edge)
    case edge
    when EntityGraph::LabelEdge
      cytoscape_label_edge(edge)
    when EntityGraph::Edge
      cytoscape_relationship_edge(edge)
    end
  end

  def cytoscape_entity_node(node)
    path = entity_node_path(node)
    entity = node.entity.decorate(context: context)
    classes = path.present? ? ['linkable'] : []
    { data: { label: entity.name, id: node.id, path: path }, classes: classes }
  end

  def cytoscape_label_node(node)
    label = I18n.t("entity_graph.labels.#{node.label_key}", node.label_data)
    path = label_node_path(node)
    { data: { label: label, id: node.id, path: path }, classes: ['label'] }
  end

  def cytoscape_relationship_edge(edge)
    { data: { source: edge.source_id, target: edge.target_id } }
  end

  def cytoscape_label_edge(edge)
    {
      data: { id: edge.id, source: edge.source_id, target: edge.target_id },
      classes: ['label'],
    }
  end

  def entity_node_path(node)
    return nil if node.entity.is_a? UnknownPersonsEntity
    h.graph_entity_path(node.entity)
  end

  def label_node_path(node)
    return h.entity_path(node.entity) if node.label_key.start_with? "max_relationships"
    h.graph_entity_path(node.entity)
  end
end
