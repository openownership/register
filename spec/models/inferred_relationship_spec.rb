require 'rails_helper'

RSpec.describe InferredRelationship do
  describe '#intermediate_entities' do
    subject { InferredRelationship.new(sourced_relationships: relationships).intermediate_entities }

    context "when there are no relationships" do
      let(:relationships) { [] }

      it "returns empty array" do
        expect(subject).to eq([])
      end
    end

    context "when there are relationships" do
      let(:entities) do
        (0..3).map { Entity.new }
      end
      let(:relationships) do
        [
          Relationship.new(source: entities[0], target: entities[1]),
          Relationship.new(source: entities[1], target: entities[2]),
          Relationship.new(source: entities[2], target: entities[3])
        ]
      end

      it "returns the entities intermediate to the first and last in the chain" do
        expect(subject).to eq(entities[1..2])
      end
    end
  end
end
