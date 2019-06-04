require 'rails_helper'

RSpec.describe EntityGraphDecorator do
  let(:entity) { create :legal_entity }
  let(:graph) { EntityGraph.new entity }
  let(:context) { { should_transliterate: false } }
  let(:decorated) { graph.decorate context: context }

  describe '#cytoscape_data' do
    subject { decorated.cytoscape_data }

    it 'has a json version of nodes and edges' do
      elements = JSON.parse subject[:elements]
      node_ids = elements['nodes'].map { |e| e['data']['id'] }
      edge_ids = elements['edges'].map { |e| e['data']['id'] }
      expect(node_ids).to match_array graph.nodes.map(&:id)
      expect(edge_ids).to match_array graph.edges.map(&:id)
    end

    it 'has the selected entity id' do
      expect(subject[:selected]).to eq entity.id.to_s
    end
  end

  describe 'generating entity nodes' do
    subject { JSON.parse(decorated.cytoscape_data[:elements])['nodes'] }

    it 'prints a nice entity name for the label' do
      expect(subject.first['data']['label']).to eq entity.name
      expect(subject.last['data']['label']).to eq 'Unknown'
    end

    context 'when asked for transliterated version' do
      let(:entity) { create(:legal_entity, name: 'тест company', lang_code: 'uk') }
      let(:context) { { should_transliterate: true } }

      it 'transliterates the entity name on the label' do
        expect(subject.first['data']['label']).to eq 'test company'
      end
    end
  end

  describe 'generating relationship edges' do
    let(:person) { create(:natural_person) }
    let!(:relationship) { create(:relationship, source: person, target: entity) }

    subject { JSON.parse(decorated.cytoscape_data[:elements])['edges'].first }

    it 'sets source and target' do
      expect(subject['data']['source']).to eq person.id.to_s
      expect(subject['data']['target']).to eq entity.id.to_s
    end
  end

  describe 'generating labels' do
    let(:label_key) { 'max_levels_relationships_as_source' }
    let(:label_data) { { count: 1 } }
    let(:label) do
      EntityGraph::LabelNode.new(entity, label_key, label_data)
    end
    let(:edge) { EntityGraph::LabelEdge.new(entity, label, :from) }

    before do
      graph.nodes << label
      graph.edges << edge
    end

    describe 'generating nodes' do
      subject { JSON.parse(decorated.cytoscape_data[:elements])['nodes'].last }

      it 'uses the right translation string for the label' do
        expected = I18n.t("entity_graph.labels.#{label_key}", label_data)
        expect(subject['data']['label']).to eq expected
      end

      it 'adds the label class' do
        expect(subject['classes']).to include 'label'
      end
    end

    describe 'generating edges' do
      subject { JSON.parse(decorated.cytoscape_data[:elements])['edges'].last }

      it 'sets source and target' do
        expect(subject['data']['source']).to eq entity.id.to_s
        expect(subject['data']['target']).to eq label.id
      end

      it 'adds the label class' do
        expect(subject['classes']).to include 'label'
      end
    end
  end
end
