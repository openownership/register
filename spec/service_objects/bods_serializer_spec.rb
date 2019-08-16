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
      expect(mapper).to receive(:generates_statement?)
        .with(legal_entity_2)
        .and_return(true)
        .once
      expect(mapper).to receive(:generates_statement?)
        .with(natural_person)
        .and_return(true)
        .once

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

  context 'when a relationship with a totally unknown owner is passed' do
    let(:entity) { create(:legal_entity) }
    let(:relationships) do
      CreateRelationshipsForStatements.call(entity)
    end

    it "should return BODS statements for the entity and an unspecified ownership" do
      expect(mapper).to receive(:generates_statement?)
        .with(relationships.first.source)
        .and_return(false)
        .once

      expect(mapper).to receive(:statement_id)
        .with(entity)
        .and_return(:legal_entity_1)
        .once
      expect(mapper).to receive(:statement_id)
        .with(relationships.first)
        .and_return(:relationship_1)
        .once

      expect(mapper).to receive(:entity_statement)
        .with(entity)
        .and_return(statementID: :legal_entity_1)
      expect(mapper).to receive(:ownership_or_control_statement)
        .with(relationships.first)
        .and_return(statementID: :relationship_1)

      expected_statements = [
        { statementID: :legal_entity_1 },
        { statementID: :relationship_1 },
      ]

      expect(subject.statements).to match_array expected_statements
    end
  end

  context "when a relationship with a declared 'no owner' is passed" do
    let :relationships do
      statement = create(:statement, type: 'psc-exists-but-not-identified')
      CreateRelationshipsForStatements.call(statement.entity)
    end

    it "should return BODS statements for the entity and it's unknown ownership" do
      expect(mapper).to receive(:generates_statement?)
        .with(relationships.first.source)
        .and_return(true)
        .once

      expect(mapper).to receive(:statement_id)
        .with(relationships.first.target)
        .and_return(:legal_entity_1)
        .once
      expect(mapper).to receive(:statement_id)
        .with(relationships.first.source)
        .and_return(:natural_person_1)
        .once
      expect(mapper).to receive(:statement_id)
        .with(relationships.first)
        .and_return(:relationship_1)
        .once

      expect(mapper).to receive(:entity_statement)
        .with(relationships.first.target)
        .and_return(statementID: :legal_entity_1)
      expect(mapper).to receive(:person_statement)
        .with(relationships.first.source)
        .and_return(statementID: :natural_person_1)
      expect(mapper).to receive(:ownership_or_control_statement)
        .with(relationships.first)
        .and_return(statementID: :relationship_1)

      expected_statements = [
        { statementID: :legal_entity_1 },
        { statementID: :natural_person_1 },
        { statementID: :relationship_1 },
      ]

      expect(subject.statements).to match_array expected_statements
    end
  end
end
