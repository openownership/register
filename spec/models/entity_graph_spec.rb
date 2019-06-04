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
  let(:expected_node_ids) { entities.map { |e| e.id.to_s } }
  let(:expected_edge_ids) do
    relationships.map { |r| "#{r.source_id}_#{r.target_id}" }
  end

  it 'visits all the owners of an entity and everything they own' do
    entities.each do |entity|
      graph = EntityGraph.new(entity)
      expect(graph.nodes.length).to eq 5
      expect(graph.nodes.map(&:id)).to match_array(expected_node_ids)
      expect(graph.edges.length).to eq 4
      expect(graph.edges.map(&:id)).to match_array expected_edge_ids
    end
  end

  it 'includes a node and edge for unknown owners' do
    entity = create(:legal_entity)
    graph = EntityGraph.new(entity)
    expect(graph.nodes.length).to eq 2
    expect(graph.nodes.map(&:id)).to match_array [entity.id.to_s, "#{entity.id}-unknown"]
    expect(graph.edges.length).to eq 1
    expect(graph.edges.first.id).to eq "#{entity.id}-unknown_#{entity.id}"
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

    before do
      expected_node_ids.concat extra_entities.map { |e| e.id.to_s }
      expected_edge_ids.concat extra_relationships.map { |r| "#{r.source_id}_#{r.target_id}" }
    end

    it 'stops at MAX_LEVELS owners' do
      last_entity = entities[3]
      label_node = EntityGraph::LabelNode.new(last_entity, :max_levels_relationships_as_target, count: 1)
      label_edge = EntityGraph::LabelEdge.new(last_entity, label_node, :to)
      expected_node_ids << label_node.id
      expected_edge_ids << label_edge.id
      excluded_node_id = entities.last.id.to_s
      expected_node_ids.reject! { |id| id == excluded_node_id }
      excluded_edge_id = "#{excluded_node_id}_#{last_entity.id}"
      expected_edge_ids.reject! { |id| id == excluded_edge_id }

      graph = EntityGraph.new(extra_entities.first)
      expect(graph.nodes.length).to eq 9
      expect(graph.nodes.map(&:id)).to match_array expected_node_ids
      expect(graph.edges.length).to eq 8
      expect(graph.edges.map(&:id)).to match_array expected_edge_ids
    end

    it 'stops at MAX_LEVELS owned companies' do
      last_entity = extra_entities[1]
      label_node = EntityGraph::LabelNode.new(last_entity, :max_levels_relationships_as_source, count: 1)
      label_edge = EntityGraph::LabelEdge.new(last_entity, label_node, :from)
      expected_node_ids << label_node.id
      expected_edge_ids << label_edge.id
      excluded_node_id = extra_entities.first.id.to_s
      expected_node_ids.reject! { |id| id == excluded_node_id }
      excluded_edge_id = "#{last_entity.id}_#{excluded_node_id}"
      expected_edge_ids.reject! { |id| id == excluded_edge_id }

      graph = EntityGraph.new(entities.last)
      expect(graph.nodes.length).to eq 9
      expect(graph.nodes.map(&:id)).to match_array expected_node_ids
      expect(graph.edges.length).to eq 8
      expect(graph.edges.map(&:id)).to match_array expected_edge_ids
    end
  end

  it 'stops at any node with MAX_RELATIONSHIPS owners' do
    entity = create(:legal_entity)
    owners = create_list(:natural_person, 16)
    owners.map { |o| create(:relationship, source: o, target: entity) }

    label_node = EntityGraph::LabelNode.new(entity, :max_relationships_relationships_as_target, count: 15)
    label_edge = EntityGraph::LabelEdge.new(entity, label_node, :to)

    graph = EntityGraph.new(entity)

    expect(graph.nodes.map(&:id)).to match_array [entity.id.to_s, label_node.id]
    expect(graph.edges.map(&:id)).to match_array [label_edge.id]
  end

  it 'stops at any node with MAX_RELATIONSHIPS owned companies' do
    owner = create(:natural_person)
    entities = create_list(:legal_entity, 16)
    entities.map { |e| create(:relationship, source: owner, target: e) }

    label_node = EntityGraph::LabelNode.new(owner, :max_relationships_relationships_as_source, count: 15)
    label_edge = EntityGraph::LabelEdge.new(owner, label_node, :from)

    graph = EntityGraph.new(owner)

    expect(graph.nodes.map(&:id)).to match_array [owner.id.to_s, label_node.id]
    expect(graph.edges.map(&:id)).to match_array [label_edge.id]
  end

  it 'stops at a circular ownership' do
    company = create(:legal_entity)
    person = create(:natural_person)
    create(:relationship, source: person, target: company)
    create(:relationship, source: company, target: company)
    expected_edge_ids = [
      "#{person.id}_#{company.id}",
      "#{company.id}_#{company.id}",
    ]
    graph = EntityGraph.new(company)
    expect(graph.nodes.length).to eq 2
    expect(graph.nodes.map(&:id)).to match_array [person.id.to_s, company.id.to_s]
    expect(graph.edges.length).to eq 2
    expect(graph.edges.map(&:id)).to match_array expected_edge_ids
  end
end
