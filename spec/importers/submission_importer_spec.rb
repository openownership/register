require 'rails_helper'

RSpec.describe SubmissionImporter do
  let(:submission) { create(:submitted_submission, submitted_at: Time.zone.parse('2017-03-01')) }
  let(:entity_resolver) { instance_double('EntityResolver') }
  let(:index_entity_service) { instance_double('IndexEntityService') }

  subject { described_class.new(submission, entity_resolver: entity_resolver) }

  describe '#import' do
    before do
      allow(IndexEntityService).to receive(:new).and_return(index_entity_service)
      allow(index_entity_service).to receive(:call)
      allow(entity_resolver).to receive(:resolve!)
    end

    context 'when there is a company' do
      let(:company) { submission.entities.legal_entities.first }

      it 'resolves the company' do
        subject.import

        expect(entity_resolver).to have_received(:resolve!).with(having_attributes(
          jurisdiction_code: company.jurisdiction_code,
          company_number: company.company_number,
          name: company.name,
        ))
      end

      context 'when the company does not resolve' do
        before do
          allow(entity_resolver).to receive(:resolve!).with(having_attributes(
            jurisdiction_code: company.jurisdiction_code,
            company_number: company.company_number,
            name: company.name,
          )).and_return(nil)

          subject.import
        end

        it 'creates an entity with an identifier' do
          entity = Entity.find_by(name: company.name)
          expect(entity.identifiers.first).to eq(
            'submission_id' => submission.id,
            'entity_id' => company.id,
          )
        end
      end
    end

    context 'when there is a person' do
      let(:person) { submission.entities.natural_persons.first }

      before { subject.import }

      it 'creates an entity with an identifier' do
        entity = Entity.find_by(name: person.name)
        expect(entity.identifiers.first).to eq(
          'submission_id' => submission.id,
          'entity_id' => person.id,
        )
      end
    end

    it 'creates relationships' do
      company = submission.entities.legal_entities.first
      person = submission.entities.natural_persons.first

      expect { subject.import }.to change { Relationship.count }

      relationship = Relationship.last

      expect(relationship.id).to eq(
        'submission_id' => submission.id,
        'relationship_id' => submission.relationships.first.id,
      )
      expect(relationship.source.name).to eq(person.name)
      expect(relationship.target.name).to eq(company.name)
      expect(relationship.interests).to eq(submission.relationships.first.interests)
      expect(relationship.sample_date).to eq(ISO8601::Date.new('2017-03-01'))
      expect(relationship.provenance.source_url).to eq('https://register.openownership.org')
      expect(relationship.provenance.source_name).to eq('OpenOwnership Register')
      expect(relationship.provenance.retrieved_at).to eq(submission.submitted_at)
      expect(relationship.provenance.imported_at).to be_a(Time)
    end

    it 'creates relationships idempotently' do
      subject.import
      expect { subject.import }.not_to change { Relationship.count }
    end
  end
end
