require 'rails_helper'

RSpec.describe EntityGraph do
  let!(:entities) do
    # A chain like a <- b <- c <- d <- e
    entities = create_list(:legal_entity, 4)
    entities << create(:natural_person)
  end
  let!(:relationships) do
    entities.each_with_index.drop(1).map do |e, i|
      create(:relationship, source: e, target: entities[i - 1])
    end
  end

  it 'visits all the owners of an entity and everything they own' do
    entities.each do |entity|
      graph = EntityGraph.new(entity)
      expect(graph.nodes.length).to eq 5
      expect(graph.nodes.map(&:entity)).to match_array(entities)
      expect(graph.edges.length).to eq 4
      expect(graph.edges.map(&:relationship)).to match_array relationships
    end
  end

  it 'includes a node and edge for unknown owners' do
    entity = create(:legal_entity)
    graph = EntityGraph.new(entity)
    expect(graph.nodes.length).to eq 2
    expect(graph.nodes.map { |n| n.entity.id.to_s }).to match_array [entity.id.to_s, "#{entity.id}-unknown"]
    expect(graph.edges.length).to eq 1
    expect(graph.edges.first.source_id).to eq "#{entity.id}-unknown"
    expect(graph.edges.first.target_id).to eq entity.id.to_s
  end

  context 'when there are more than MAX_LEVELS nodes in the chain' do
    let!(:extra_entities) { create_list(:legal_entity, 4) }
    let!(:extra_relationships) do
      # Add more companies underneath: f <- g <- h <- i <- a <- b <- c <- d <- e
      relationships = extra_entities.each_with_index.drop(1).map do |e, i|
        create(:relationship, source: e, target: extra_entities[i - 1])
      end
      relationships << create(:relationship, source: entities.first, target: extra_entities.last)
    end

    it 'stops at MAX_LEVELS owners' do
      last_entity = entities[3]
      label_node = EntityGraph::LabelNode.new(last_entity, :max_levels_relationships_as_target, count: 1)
      label_edge = EntityGraph::LabelEdge.new(last_entity, label_node, :to)

      graph = EntityGraph.new(extra_entities.first)
      expect(graph.nodes.length).to eq 9
      expect(graph.nodes.map(&:entity).uniq).to match_array entities.first(4) + extra_entities
      expect(graph.nodes).to include(label_node)

      expect(graph.edges.length).to eq 8
      expect(graph.edges.map(&:relationship).compact).to match_array relationships.first(3) + extra_relationships
      expect(graph.edges).to include(label_edge)
    end

    it 'stops at MAX_LEVELS owned companies' do
      last_entity = extra_entities[1]
      label_node = EntityGraph::LabelNode.new(last_entity, :max_levels_relationships_as_source, count: 1)
      label_edge = EntityGraph::LabelEdge.new(last_entity, label_node, :from)

      graph = EntityGraph.new(entities.last)

      expect(graph.nodes.length).to eq 9
      expect(graph.nodes.map(&:entity).uniq).to match_array entities + extra_entities.drop(1)
      expect(graph.nodes).to include(label_node)

      expect(graph.edges.length).to eq 8
      expect(graph.edges.map(&:relationship).compact).to match_array relationships + extra_relationships.drop(1)
      expect(graph.edges).to include(label_edge)
    end
  end

  it 'stops at any node with MAX_RELATIONSHIPS owners' do
    entity = create(:legal_entity)
    owners = create_list(:natural_person, 26)
    owners.map { |o| create(:relationship, source: o, target: entity) }

    label_node = EntityGraph::LabelNode.new(entity, :max_relationships_relationships_as_target, count: 15)
    label_edge = EntityGraph::LabelEdge.new(entity, label_node, :to)

    graph = EntityGraph.new(entity)

    expect(graph.nodes.length).to eq 2
    expect(graph.nodes.map(&:entity).uniq).to match_array [entity]
    expect(graph.nodes).to include(label_node)

    expect(graph.edges.map(&:id)).to match_array [label_edge.id]
  end

  it 'stops at any node with MAX_RELATIONSHIPS owned companies' do
    owner = create(:natural_person)
    entities = create_list(:legal_entity, 26)
    entities.map { |e| create(:relationship, source: owner, target: e) }

    label_node = EntityGraph::LabelNode.new(owner, :max_relationships_relationships_as_source, count: 15)
    label_edge = EntityGraph::LabelEdge.new(owner, label_node, :from)

    graph = EntityGraph.new(owner)

    expect(graph.nodes.length).to eq 2
    expect(graph.nodes.map(&:entity).uniq).to match_array [owner]
    expect(graph.nodes).to include(label_node)
    expect(graph.edges.map(&:id)).to match_array [label_edge.id]
  end

  it 'stops at a circular ownership' do
    company = create(:legal_entity)
    person = create(:natural_person)
    ownership = create(:relationship, source: person, target: company)
    circular_ownership = create(:relationship, source: company, target: company)
    graph = EntityGraph.new(company)
    expect(graph.nodes.length).to eq 2
    expect(graph.nodes.map(&:entity)).to match_array [person, company]
    expect(graph.edges.length).to eq 2
    expect(graph.edges.map(&:relationship)).to match_array [ownership, circular_ownership]
  end

  it 'allows multiple different relationships between the same nodes' do
    company = create(:legal_entity)
    person = create(:natural_person)
    ownership_one = create(:relationship, source: person, target: company, interests: ['shares-50%'])
    ownership_two = create(:relationship, source: person, target: company, interests: ['other-control'])
    graph = EntityGraph.new(company)

    expect(graph.nodes.length).to eq 2
    expect(graph.edges.length).to eq 2
    expect(graph.edges.map(&:relationship)).to match_array [ownership_one, ownership_two]
  end

  it 'de-dupes relationships on the same node' do
    company = create(:legal_entity)
    person = create(:natural_person)
    ownership = create(:relationship, source: person, target: company)
    graph = EntityGraph.new(company)

    graph.edges.add EntityGraph::Edge.new(ownership)

    expect(graph.edges.length).to eq 1
    expect(graph.edges.map(&:relationship)).to match_array [ownership]
  end

  it 'allows multiple different labels on the same node' do
    entity = create(:legal_entity)
    graph = EntityGraph.new(entity)

    label_one = EntityGraph::LabelNode.new(entity, 'key_1', {})
    label_two = EntityGraph::LabelNode.new(entity, 'key_2', {})
    graph.nodes.add(label_one)
    graph.nodes.add(label_two)
    graph.edges.add EntityGraph::LabelEdge.new(entity, label_one, :to)
    graph.edges.add EntityGraph::LabelEdge.new(entity, label_two, :to)

    expect(graph.nodes.length).to eq 4 # Entity, unknown owner and two labels
    expect(graph.edges.length).to eq 3 # Unknown ownership and two labels
  end

  it 'de-dupes labels of exactly the same message on the same node' do
    entity = create(:legal_entity)
    graph = EntityGraph.new(entity)

    label_one = EntityGraph::LabelNode.new(entity, 'key_1', {})
    graph.nodes.add(label_one)
    graph.edges.add EntityGraph::LabelEdge.new(entity, label_one, :to)

    graph.nodes.add(label_one)
    graph.edges.add EntityGraph::LabelEdge.new(entity, label_one, :to)

    expect(graph.nodes.length).to eq 3 # Entity, unknown owner and one label
    expect(graph.edges.length).to eq 2 # Unknown ownership and one label
  end
end
