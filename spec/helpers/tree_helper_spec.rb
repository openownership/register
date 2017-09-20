require 'rails_helper'

RSpec.describe TreeHelper do
  describe '#tree_node_classes' do
    let(:entity) { instance_double('Entity', type: "example-type") }
    let(:tree_node) { instance_double('TreeNode', entity: entity) }

    subject { helper.tree_node_classes(tree_node) }

    before do
      allow(tree_node).to receive(:root?)
      allow(tree_node).to receive(:leaf?)
    end

    it 'includes entity type modifier' do
      expect(subject).to include('tree-node--example-type')
    end

    context 'when it is a root node' do
      it 'includes root class modifier' do
        allow(tree_node).to receive(:root?).and_return(true)
        expect(subject).to include('tree-node--root')
      end
    end

    context 'when it is a leaf node' do
      it 'includes leaf class modifier' do
        allow(tree_node).to receive(:leaf?).and_return(true)
        expect(subject).to include('tree-node--leaf')
      end
    end
  end
end
