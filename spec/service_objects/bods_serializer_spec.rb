require 'rails_helper'

RSpec.describe BodsSerializer do
  let(:mapper) { instance_double(BodsMapper) }

  subject do
    BodsSerializer.new(
      relationships,
      mapper,
    )
  end

  context 'when no relationships are passed' do
    let(:relationships) { [] }

    it 'returns an empty list' do
      expect(subject.statements).to eq []
    end
  end

  context 'when a chain of relationships are passed' do
    let(:legal_entity_1) { create :legal_entity }
    let(:legal_entity_2) { create :legal_entity }
    let(:natural_person) { create :natural_person }

    let(:relationships) do
      [
        create(:relationship, source: legal_entity_2, target: legal_entity_1),
        create(:relationship, source: natural_person, target: legal_entity_2),
      ]
    end

    it 'should return a list of BODS statements for the whole chain' do
      expect(mapper).to receive(:statement_id)
        .with(legal_entity_1)
        .and_return(:legal_entity_1)
        .once
      expect(mapper).to receive(:entity_statement)
        .with(legal_entity_1)
        .and_return(statementID: :legal_entity_1)

      expect(mapper).to receive(:statement_id)
        .with(legal_entity_2)
        .and_return(:legal_entity_2)
        .twice
      expect(mapper).to receive(:entity_statement)
        .with(legal_entity_2)
        .and_return(statementID: :legal_entity_2)

      expect(mapper).to receive(:statement_id)
        .with(natural_person)
        .and_return(:natural_person)
        .once
      expect(mapper).to receive(:person_statement)
        .with(natural_person)
        .and_return(statementID: :natural_person)

      expect(mapper).to receive(:statement_id)
        .with(relationships.first)
        .and_return(:relationship_1)
        .once
      expect(mapper).to receive(:ownership_or_control_statement)
        .with(relationships.first)
        .and_return(statementID: :relationship_1)

      expect(mapper).to receive(:statement_id)
        .with(relationships.second)
        .and_return(:relationship_2)
        .once
      expect(mapper).to receive(:ownership_or_control_statement)
        .with(relationships.second)
        .and_return(statementID: :relationship_2)

      expected_statements = [
        { statementID: :legal_entity_1 },
        { statementID: :legal_entity_2 },
        { statementID: :natural_person },
        { statementID: :relationship_1 },
        { statementID: :relationship_2 },
      ]

      expect(subject.statements).to match_array expected_statements
    end
  end

  context 'when a relationship with an UnknownPersonsEntity is passed' do
    let :relationships do
      [create(:relationship, source: UnknownPersonsEntity.new)]
    end

    it 'should ignore the relationship and not return any statements' do
      expect(subject.statements).to eq []
    end
  end
end
