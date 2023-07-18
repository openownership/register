class EntityGraphDecorator < ApplicationDecorator
  delegate_all

  # decorates_association :entity

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
    entity = node.entity #.decorate(context: context)
    classes = entity.dissolution_date ? ['dissolved'] : []
    tooltip = nil
    unless entity.is_unknown?
      tooltip = h.render(
        partial: 'entities/graph_tooltip',
        locals: { entity: entity },
      )
    end
    {
      data: {
        label: entity.name,
        id: node.id,
        tooltip: tooltip,
        flag: h.country_flag_path(entity.country),
      },
      classes: classes,
    }
  end

  def cytoscape_label_node(node)
    entity = node.entity #.decorate(context: context)
    label = I18n.t("entity_graph.labels.#{node.label_key}", **node.label_data)
    show_graph_link = node.label_key.start_with? 'max_levels'
    tooltip = h.render(
      partial: 'entity_graphs/error_tooltip',
      locals: {
        error_message: label,
        entity: entity,
        show_graph_link: show_graph_link,
      },
    )
    {
      data: { label: label, id: node.id, tooltip: tooltip },
      classes: ['label'],
    }
  end

  def cytoscape_relationship_edge(edge)
    classes = edge.source_id == edge.target_id ? ['circular'] : []
    relationship = edge.relationship #.decorate(context: context)
    classes << 'ended' if relationship.ended_date
    {
      data: {
        id: edge.id,
        source: edge.source_id,
        target: edge.target_id,
        tooltip: h.render(
          partial: "relationships/graph_tooltip",
          locals: { relationship: relationship },
        ),
      },
      classes: classes,
    }
  end

  def cytoscape_label_edge(edge)
    {
      data: { id: edge.id, source: edge.source_id, target: edge.target_id },
      classes: ['label'],
    }
  end
end
