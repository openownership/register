require 'rails_helper'

RSpec.describe EitiImporter do
  let(:opencorporates_client) { instance_double('OpencorporatesClient') }

  let(:entity_resolver) { instance_double('EntityResolver') }

  let(:source_name) { 'EITI pilot data' }

  let(:retrieved_at) { Time.zone.local(2011, 2, 3, 4, 5, 6) }

  let(:document_id) { 'EITI Structured Data - Jurisdiction Standardised' }

  subject do
    EitiImporter.new(opencorporates_client: opencorporates_client, entity_resolver: entity_resolver).tap do |importer|
      importer.source_name = source_name
      importer.retrieved_at = retrieved_at
      importer.document_id = document_id
      importer.source_jurisdiction_code = 'ng'
    end
  end

  describe '#parse' do
    before do
      allow(opencorporates_client).to receive(:get_jurisdiction_code)
      allow(entity_resolver).to receive(:resolve!)
    end

    context 'when the child company jurisdiction matches' do
      before do
        allow(opencorporates_client).to receive(:get_jurisdiction_code).with('UK').and_return('gb')
      end

      it 'resolves the child company' do
        subject.parse(file_fixture('eiti_individual.csv'))

        expect(entity_resolver).to have_received(:resolve!).with(
          having_attributes(
            jurisdiction_code: 'gb',
            company_number: '12345',
            name: 'Example Child',
          ),
        )
      end
    end

    context 'when the child company jurisdiction does not match' do
      before do
        allow(opencorporates_client).to receive(:get_jurisdiction_code).with('UK').and_return(nil)
      end

      it 'resolves the child company with the source jurisdiction_code' do
        subject.parse(file_fixture('eiti_individual.csv'))

        expect(entity_resolver).to have_received(:resolve!).with(
          having_attributes(
            jurisdiction_code: 'ng',
            company_number: '12345',
            name: 'Example Child',
          ),
        )
      end
    end

    it 'creates an entity with a document based identifier' do
      subject.parse(file_fixture('eiti_individual.csv'))

      entity = Entity.find_by(name: 'Example Child')

      expect(entity.identifiers.first).to eq(
        'document_id' => document_id,
        'name' => 'Example Child',
      )
    end

    it 'sets the type of entity to Entity::Types::LEGAL_ENTITY' do
      subject.parse(file_fixture('eiti_individual.csv'))

      entity = Entity.find_by(name: 'Example Child')
      expect(entity.type).to eq(Entity::Types::LEGAL_ENTITY)
    end

    it 'sets the entity jurisdiction' do
      subject.parse(file_fixture('eiti_individual.csv'))

      entity = Entity.find_by(name: "Example Child")
      expect(entity.jurisdiction_code).to eq('ng')
    end

    context 'when the parent entity is labelled as an individual' do
      let(:file) { file_fixture('eiti_individual.csv') }

      before do
        subject.parse(file)
      end

      it 'creates an entity with a document based identifier' do
        entity = Entity.find_by(name: 'Example Person')

        expect(entity.identifiers.first).to eq(
          'document_id' => document_id,
          'name' => 'Example Person',
        )
      end

      it 'sets the type of entity to Entity::Types::NATURAL_PERSON' do
        entity = Entity.find_by(name: 'Example Person')
        expect(entity.type).to eq(Entity::Types::NATURAL_PERSON)
      end
    end

    context 'when the parent entity is not labelled as an individual' do
      let(:file) { file_fixture('eiti_corporate.csv') }

      context 'when the parent entity jurisdiction matches' do
        before do
          allow(opencorporates_client).to receive(:get_jurisdiction_code).with('UK').and_return('gb')
        end

        it 'resolves the parent entity' do
          subject.parse(file)

          expect(entity_resolver).to have_received(:resolve!).with(
            having_attributes(
              jurisdiction_code: 'gb',
              company_number: nil,
              name: 'Example Parent',
            ),
          )
        end

        it 'creates an entity with a document based identifier' do
          subject.parse(file)

          entity = Entity.find_by(name: 'Example Parent')

          expect(entity.identifiers.first).to eq(
            'document_id' => document_id,
            'name' => 'Example Parent',
          )
        end

        it 'sets the type of entity to Entity::Types::LEGAL_ENTITY' do
          subject.parse(file)

          entity = Entity.find_by(name: 'Example Parent')
          expect(entity.type).to eq(Entity::Types::LEGAL_ENTITY)
        end

        it 'sets the entity jurisdiction to the matched one' do
          subject.parse(file)

          entity = Entity.find_by(name: 'Example Parent')
          expect(entity.jurisdiction_code).to eq('gb')
        end
      end

      context 'when the parent entity jurisdiction does not match' do
        before do
          allow(opencorporates_client).to receive(:get_jurisdiction_code).with('UK').and_return(nil)

          subject.parse(file)
        end

        it 'creates an entity with a document based identifier' do
          entity = Entity.find_by(name: 'Example Parent')

          expect(entity.identifiers.first).to eq(
            'document_id' => document_id,
            'name' => 'Example Parent',
          )
        end

        it 'sets the type of entity to Entity::Types::LEGAL_ENTITY' do
          entity = Entity.find_by(name: 'Example Parent')
          expect(entity.type).to eq(Entity::Types::LEGAL_ENTITY)
        end
      end
    end

    it 'creates relationships between child and parent entities' do
      subject.parse(file_fixture('eiti_corporate.csv'))

      expect(Relationship.count).to eq(1)

      relationship = Relationship.first

      expect(relationship.source).to eq(Entity.find_by(name: 'Example Parent'))
      expect(relationship.target).to eq(Entity.find_by(name: 'Example Child'))
      expect(relationship.interests).to eq(['Shareholding'])
      expect(relationship.sample_date).to eq(ISO8601::Date.new('2014'))
      expect(relationship.provenance.source_url).to eq('https://example.com/corporate-bo-filing.pdf')
      expect(relationship.provenance.source_name).to eq(source_name)
      expect(relationship.provenance.retrieved_at).to eq(retrieved_at)
      expect(relationship.provenance.imported_at).to be_a(Time)
    end

    it 'creates relationships idempotently' do
      file = file_fixture('eiti_individual.csv')

      subject.parse(file)

      expect { subject.parse(file) }.not_to change { Relationship.count }
    end

    context 'when the csv file does not have the expected columns' do
      it 'raises an exception' do
        file = file_fixture('eiti_invalid_columns.csv')

        expect { subject.parse(file) }.to raise_error(EitiImporter::ColumnError)
      end
    end
  end
end
