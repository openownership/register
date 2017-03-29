require 'rails_helper'

RSpec.describe TreeNode do
  let(:entity) { instance_double('Entity') }
  let(:relationship) { instance_double('Relationship') }

  subject { described_class.new(entity) }

  describe "#nodes" do
    context "recursive relationship" do
      before do
        allow(entity).to receive(:relationships_as_target_excluding).with([]).and_return([relationship])
        allow(relationship).to receive(:id).and_return('test-id')
        allow(relationship).to receive(:source).and_return(entity)
        allow(entity).to receive(:relationships_as_target_excluding).with(['test-id']).and_return([])
      end

      it "returns the node once" do
        expect(subject.nodes.size).to eq(1)
        expect(subject.nodes.first.nodes.size).to eq(0)
      end
    end
  end

  describe "#leaf_nodes" do
    context "has no nodes" do
      before do
        allow(entity).to receive(:relationships_as_target_excluding).and_return([])
      end

      it "returns self" do
        expect(subject.leaf_nodes).to eq([subject])
      end
    end

    context "has nodes" do
      let(:entity_1) { instance_double('Entity') }
      let(:entity_2) { instance_double('Entity') }
      let(:relationship_1) { instance_double('Relationship', id: 'test-id-1') }
      let(:relationship_2) { instance_double('Relationship', id: 'test-id-2') }

      before do
        allow(entity).to receive(:relationships_as_target_excluding).and_return([relationship_1])
        allow(relationship_1).to receive(:source).and_return(entity_1)
        allow(entity_1).to receive(:relationships_as_target_excluding).and_return([relationship_2])
        allow(relationship_2).to receive(:source).and_return(entity_2)
        allow(entity_2).to receive(:relationships_as_target_excluding).and_return([])
      end

      it "returns the leaf nodes" do
        expect(subject.leaf_nodes.size).to eq(1)
        expect(subject.leaf_nodes.first.entity).to eq(entity_2)
        expect(subject.leaf_nodes.first.relationship).to eq(relationship_2)
      end
    end
  end
end
