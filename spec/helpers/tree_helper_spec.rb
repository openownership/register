require 'rails_helper'

RSpec.describe TreeHelper do
  describe '#tree_node_classes' do
    let(:entity) { instance_double('Entity') }
    let(:relationship) { instance_double('Relationship') }

    subject { helper.tree_node_classes(entity, relationship) }

    before do
      allow(entity).to receive(:type)
      allow(entity).to receive(:natural_person?)
      allow(relationship).to receive(:nil?)
    end

    it 'includes entity type modifier' do
      allow(entity).to receive(:type).and_return('example-type')
      expect(subject).to include('tree-node--example-type')
    end

    context 'when it is a root node' do
      it 'includes root class modifier' do
        allow(relationship).to receive(:nil?).and_return(true)
        expect(subject).to include('tree-node--root')
      end
    end

    context 'when it is a leaf node' do
      it 'includes leaf class modifier' do
        allow(entity).to receive(:natural_person?).and_return(true)
        expect(subject).to include('tree-node--leaf')
      end
    end
  end
end
