require 'rails_helper'

RSpec.describe CreateRelationshipsForStatements do
  describe '.call' do
    context 'when the source entity has Statements' do
      let(:statement) do
        create(:statement, id: { 'identifier' => 'test' }, date: '2019-01-01')
      end
      let(:second_statement) { create(:statement, entity: statement.entity) }

      subject { CreateRelationshipsForStatements.call(second_statement.entity) }

      it 'creates a relationship for each statement' do
        expect(subject.length).to eq 2
      end

      it 'gives the relationships an id' do
        expected = {
          'document_id' => 'OpenOwnership Register',
          'statement_id' => { 'identifier' => 'test' },
        }
        expect(subject.first.id).to eq expected
      end

      describe 'setting the relationship source' do
        it 'sets the source to an UnknownPersonsEntity' do
          expect(subject.first.source).to be_a UnknownPersonsEntity
        end

        it 'gives it an id from the Statement type' do
          expect(subject.first.source.id).to eq('statement-descriptions-no-individual-or-entity-with-signficant-control')
        end

        it 'gives it a name from the translated description of the Statement type' do
          expected = "The company knows or has reasonable cause to believe that there is no registrable person or registrable relevant legal entity in relation to the company"
          expect(subject.first.source.name).to eq(expected)
        end
      end

      it 'sets the source entity as the relationship target' do
        expect(subject.first.target).to eq(statement.entity)
      end

      describe 'setting the sample_date' do
        it 'sets it as an ISO8601::Date object' do
          expect(subject.first.sample_date).to be_a ISO8601::Date
        end

        it 'sets it from the Statement date' do
          expect(subject.first.sample_date.to_s).to eq '2019-01-01'
        end

        context "when there's no statement date" do
          before do
            statement.date = nil
          end

          it 'sets it to nil' do
            expect(subject.first.sample_date).to be_nil
          end
        end
      end

      context 'when the statement has an ended_date' do
        before do
          statement.ended_date = '2019-01-01'
        end

        it 'sets it as an ISO8601::Date object' do
          expect(subject.first.ended_date).to be_a ISO8601::Date
        end

        it 'sets the ended_date on the relationship' do
          expect(subject.first.ended_date.to_s).to eq('2019-01-01')
        end
      end

      context 'when the statement has raw_data_provenances' do
        before do
          create(:raw_data_provenance, entity_or_relationship: statement)
        end

        it 'sets the raw_data_provenances' do
          expect(subject.first.raw_data_provenances).to eq(statement.raw_data_provenances)
        end
      end
    end

    context 'when the source entity has no Statements' do
      let(:entity) { create(:legal_entity, id: '123456') }

      subject { CreateRelationshipsForStatements.call(entity) }

      it 'creates a single relationship' do
        expect(subject.length).to eq(1)
      end

      it 'gives the relationship an id using the entity id' do
        expected = {
          'document_id' => 'OpenOwnership Register',
          'identifier' => '123456-unknown-relationship',
        }
        expect(subject.first.id).to eq(expected)
      end

      describe 'setting the relationship source' do
        it 'sets the source to an UnknownPersonsEntity' do
          expect(subject.first.source).to be_a UnknownPersonsEntity
        end

        it 'gives it an id from the entity id' do
          expect(subject.first.source.id).to eq '123456-unknown'
        end
      end

      it 'sets the source entity as the relationship target' do
        expect(subject.first.target).to eq entity
      end
    end
  end
end
