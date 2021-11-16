require 'rails_helper'
require 'support/fixture_helpers'

RSpec.describe PscImporter do
  let(:opencorporates_client) { instance_double('OpencorporatesClient') }
  let(:entity_resolver) { instance_double('EntityResolver') }
  let(:index_entity_service) { instance_double('IndexEntityService') }
  let(:retrieved_at) { Time.zone.local(2011, 2, 3, 4, 5, 6) }
  let(:data_source) { create(:psc_data_source) }
  let(:import) { create(:import, data_source: data_source) }

  subject do
    PscImporter.new(opencorporates_client: opencorporates_client, entity_resolver: entity_resolver).tap do |importer|
      importer.import = import
      importer.retrieved_at = retrieved_at
    end
  end

  describe '#process_records' do
    let(:records) { psc_json_fixture('psc_individual.json') }

    before do
      allow(entity_resolver).to receive(:resolve!)

      allow(IndexEntityService).to receive(:new).and_return(index_entity_service)
      allow(index_entity_service).to receive(:index)
    end

    context 'child entity' do
      let(:jurisdiction_code) { 'gb' }
      let(:company_number) { '01234567' }

      let(:psc_identifier) do
        {
          'document_id' => data_source.document_id,
          'company_number' => company_number,
        }
      end

      def parse_then_expect_resolve_child_company_entity
        subject.process_records(records)

        expect(entity_resolver).to have_received(:resolve!)
          .with(having_attributes(
            jurisdiction_code: jurisdiction_code,
            company_number: company_number,
          ))

        entity = Entity.legal_entities.first

        expect(entity.identifiers.first).to eq psc_identifier
      end

      context 'when the child company does not exist' do
        it 'should resolve and then create the child company' do
          expect do
            parse_then_expect_resolve_child_company_entity
          end.to change { Entity.with_identifiers([psc_identifier]).count }.from(0).to(1)
        end
      end

      context 'when the child company exists' do
        let!(:entity) do
          create :legal_entity, identifiers: [psc_identifier]
        end

        context 'but does not have an OC identifier' do
          it 'should resolve and then update the existing child company' do
            expect do
              parse_then_expect_resolve_child_company_entity
            end.not_to change { Entity.with_identifiers([psc_identifier]).count }
          end
        end

        context 'and has an OC identifier' do
          before do
            entity.add_oc_identifier(
              jurisdiction_code: jurisdiction_code,
              company_number: company_number,
            )
            entity.save!
          end

          it 'should resolve and then update the existing child company' do
            expect do
              parse_then_expect_resolve_child_company_entity
            end.not_to change { Entity.with_identifiers([psc_identifier]).count }
          end
        end
      end
    end

    context 'when the parent entity is labelled as a corporate entity' do
      context 'when country_registered is not null' do
        let(:records) { psc_json_fixture('psc_corporate.json') }

        context 'when country_registered matches a jurisdiction' do
          before do
            allow(opencorporates_client).to receive(:get_jurisdiction_code).with('United Kingdom').and_return('gb')
          end

          it 'resolves the parent entity' do
            subject.process_records(records)

            expect(entity_resolver).to have_received(:resolve!).with(
              having_attributes(
                jurisdiction_code: 'gb',
                company_number: '89101112',
                name: 'Foo Bar Limited',
              ),
            )
          end

          it 'creates an entity with a document based identifier' do
            subject.process_records(psc_json_fixture("psc_corporate.json"))

            entity = Entity.find_by(name: 'Foo Bar Limited')

            expect(entity.identifiers.first).to eq(
              'document_id' => data_source.document_id,
              'link' => '/company/01234567/persons-with-significant-control/corporate-entity/abcdef123456789',
              'company_number' => '89101112',
            )
          end

          it 'sets the type of entity to Entity::Types::LEGAL_ENTITY' do
            subject.process_records(records)

            entity = Entity.find_by(name: 'Foo Bar Limited')
            expect(entity.type).to eq(Entity::Types::LEGAL_ENTITY)
          end

          it 'sets the entity jurisdiction to the matched one' do
            subject.process_records(records)

            entity = Entity.find_by(name: 'Foo Bar Limited')
            expect(entity.jurisdiction_code).to eq('gb')
          end
        end

        context 'when country_registered does not match a jurisdiction' do
          before do
            allow(opencorporates_client).to receive(:get_jurisdiction_code).with('West Yorkshire').and_return(nil)

            subject.process_records(psc_json_fixture('psc_no_match.json'))
          end

          it 'creates an entity with a document based identifier' do
            entity = Entity.find_by(name: 'Foo Bar Limited')

            expect(entity.identifiers.first).to eq(
              'document_id' => data_source.document_id,
              'link' => '/company/01234567/persons-with-significant-control/corporate-entity/abcdef123456789',
            )
          end

          it 'sets the type of entity to Entity::Types::LEGAL_ENTITY' do
            entity = Entity.find_by(name: 'Foo Bar Limited')
            expect(entity.type).to eq(Entity::Types::LEGAL_ENTITY)
          end
        end
      end

      context 'when country_registered is null' do
        let(:records) { psc_json_fixture('psc_no_country.json') }

        before do
          subject.process_records(records)
        end

        it 'creates an entity with a document based identifier' do
          entity = Entity.find_by(name: 'Foo Bar Limited')

          expect(entity.identifiers.first).to eq(
            'document_id' => data_source.document_id,
            'link' => '/company/01234567/persons-with-significant-control/corporate-entity/abcdef123456789',
          )
        end

        it 'sets the type of entity to Entity::Types::LEGAL_ENTITY' do
          entity = Entity.find_by(name: 'Foo Bar Limited')
          expect(entity.type).to eq(Entity::Types::LEGAL_ENTITY)
        end
      end
    end

    context 'when the parent entity is not labelled as a corporate entity' do
      let(:records) { psc_json_fixture('psc_individual.json') }

      before do
        subject.process_records(records)
      end

      it 'creates an entity with a document based identifier' do
        entity = Entity.find_by(name: 'Joe Bloggs')

        expect(entity.identifiers.first).to eq(
          'document_id' => data_source.document_id,
          'link' => '/company/01234567/persons-with-significant-control/individual/abcdef123456789',
        )
      end

      it 'sets the type of entity to Entity::Types::NATURAL_PERSON' do
        entity = Entity.find_by(name: 'Joe Bloggs')
        expect(entity.type).to eq(Entity::Types::NATURAL_PERSON)
      end

      it 'imports other information' do
        entity = Entity.find_by(name: 'Joe Bloggs')

        expect(entity.nationality).to eq('GB')
        expect(entity.country_of_residence).to eq('United Kingdom')
        expect(entity.address).to eq('123 Main Street, Example Town, Exampleshire, EX4 2MP')
        expect(entity.dob).to eq(ISO8601::Date.new('1955-10'))
      end
    end

    it 'creates relationships between child and parent entities' do
      subject.process_records(records)

      expect(Relationship.count).to eq(1)

      relationship = Relationship.first

      parent_entity = Entity.find_by(name: 'Joe Bloggs')

      expect(relationship.target).to eq(Entity.find_by(type: Entity::Types::LEGAL_ENTITY))
      expect(relationship.source).to eq(parent_entity)
      expect(relationship.interests).to include('ownership-of-shares-25-to-50-percent')
      expect(relationship.interests).to include('voting-rights-25-to-50-percent')
      expect(relationship.sample_date).to eq(ISO8601::Date.new('2016-04-06'))
      expect(relationship.started_date).to eq(ISO8601::Date.new('2016-04-06'))
      expect(relationship.ended_date).to be_nil
      expect(relationship.provenance.source_url).to eq(data_source.url)
      expect(relationship.provenance.source_name).to eq(data_source.name)
      expect(relationship.provenance.retrieved_at).to eq(retrieved_at)
      expect(relationship.provenance.imported_at).to be_a(Time)
    end

    it 'creates relationships idempotently' do
      subject.process_records(records)

      expect { subject.process_records(records) }.not_to change { Relationship.count }
    end

    it 'ignores totals#persons-of-significant-control-snapshot entries' do
      subject.process_records(psc_json_fixture("psc_totals.json"))

      expect(Entity.count).to eq(0)
      expect(Relationship.count).to eq(0)
    end

    context 'when there is a person with significant control statement' do
      it 'creates a statement linked to the entity' do
        allow(entity_resolver).to receive(:resolve!).with(
          having_attributes(
            jurisdiction_code: 'gb',
            company_number: '1234567',
            name: nil,
          ),
        ) do |entity_to_resolve|
          @entity = entity_to_resolve
        end

        subject.process_records(psc_json_fixture('psc_statement.json'))

        statement = @entity.statements.first

        expect(statement).to be_a(Statement)
        expect(statement.type).to eq('no-individual-or-entity-with-signficant-control')
        expect(statement.date).to eq(Date.new(2016, 7, 12))
      end

      it 'imports statements with a ceased_on data' do
        records = psc_json_fixture('psc_statement_ceased_on.json')

        expect { subject.process_records(records) }.to change { Statement.count }.by(1)
        expect(Statement.last.ended_date).to eq ISO8601::Date.new('2016-10-11')
      end
    end

    context 'when there is a super secure person with significant control' do
      it 'creates a statement linked to the entity' do
        allow(entity_resolver).to receive(:resolve!).with(
          having_attributes(
            jurisdiction_code: 'gb',
            company_number: '1234567',
            name: nil,
          ),
        ) do |entity_to_resolve|
          @entity = entity_to_resolve
        end

        subject.process_records(psc_json_fixture('psc_super_secure.json'))

        statement = @entity.statements.first

        expect(statement).to be_a(Statement)
        expect(statement.type).to eq('super-secure-person-with-significant-control')
      end
    end

    context 'when there is an exemption' do
      it 'creates a statement linked to the entity' do
        allow(entity_resolver).to receive(:resolve!).with(
          having_attributes(
            jurisdiction_code: 'gb',
            company_number: '1234567',
            name: nil,
          ),
        ) do |entity_to_resolve|
          @entity = entity_to_resolve
        end

        subject.process_records(psc_json_fixture('psc_exemptions.json'))

        statement = @entity.statements.first

        expect(statement).to be_a(Statement)
        expect(statement.type).to eq('psc-exempt-as-shares-admitted-on-market')
        expect(statement.date).to eq(Date.new(2016, 10, 29))
      end
    end

    it 'imports records with a ceased_on date' do
      records = psc_json_fixture('psc_ceased_on.json')

      expect { subject.process_records(records) }.to change { Relationship.count }.by(1)
      expect(Relationship.last.ended_date).to eq ISO8601::Date.new('2016-10-11')
    end

    it 'raises an exception when it sees an unknown kind' do
      expect do
        subject.process_records(psc_json_fixture("psc_unknown_kind.json"))
      end.to raise_error("unexpected kind: unknown-kind")
    end

    context 'when multiple entities exist matching the identifiers' do
      let(:company_number) { "89101112" }
      let(:self_link) { "/company/01234567/persons-with-significant-control/corporate-entity/abcdef123456789" }

      let :psc_identifier do
        {
          'document_id' => data_source.document_id,
          'link' => self_link,
          'company_number' => company_number,
        }
      end

      let :oc_identifier do
        {
          'jurisdiction_code' => 'gb',
          'company_number' => company_number,
        }
      end

      let! :psc_existing_entity do
        create :legal_entity, identifiers: [psc_identifier]
      end

      let! :oc_existing_entity do
        create :legal_entity, identifiers: [oc_identifier]
      end

      let(:new_name) { 'Foo Merged Ltd.' }

      before do
        allow(opencorporates_client).to receive(:get_jurisdiction_code).with('United Kingdom').and_return('gb')
      end

      it 'should merge the two existing entities into one and upsert the updated data' do
        expect(entity_resolver).to receive(:resolve!).with(
          having_attributes(
            jurisdiction_code: 'gb',
            company_number: company_number,
          ),
        ) do |e|
          e.name = new_name
          e.identifiers << oc_identifier
        end

        # NOTE: this has become more of an integration test instead of a unit
        # test, as we would like to test that the duplicate error gets triggered
        # and the entity merge actually goes through and sets the appropriate
        # state in the db as expected. Of course this means we need to mock more
        # of the 'guts' of the system, as we're now reaching into the entity
        # merge service. Not ideal.

        allow(index_entity_service).to receive(:delete)

        subject.process_records(psc_json_fixture('psc_corporate.json'))

        expect(Entity.where(id: psc_existing_entity.id).exists?).to be false

        merged_entity = Entity.find(oc_existing_entity.id)
        expect(merged_entity.identifiers).to contain_exactly oc_identifier, psc_identifier
        expect(merged_entity.name).to eq new_name
      end
    end

    it 'indexes all of the entities' do
      expect(IndexEntityService).to receive(:new).with(
        having_attributes(
          name: 'Joe Bloggs',
        ),
      )

      expect(IndexEntityService).to receive(:new).with(
        having_attributes(
          company_number: '01234567',
        ),
      )

      subject.process_records(records)
    end

    it 'creates RawDataProvenance records for entities and relationships' do
      expect do
        subject.process_records(records)
      end.to change { RawDataProvenance.count }.from(0).to(3)

      child_entity = Entity.find_by(company_number: "01234567")
      parent_entity = Entity.find_by(name: "Joe Bloggs")
      relationship = Relationship.find_by(source: parent_entity, target: child_entity)

      expect(parent_entity.raw_data_provenances.count).to eq(1)
      expect(child_entity.raw_data_provenances.count).to eq(1)
      expect(relationship.raw_data_provenances.count).to eq(1)
    end

    it 'creates RawDataProvenance records for entities and statements' do
      expect do
        subject.process_records(psc_json_fixture('psc_statement.json'))
      end.to change { RawDataProvenance.count }.from(0).to(2)
      child_entity = Entity.find_by(company_number: "1234567")
      statement = Statement.find_by(entity: child_entity)
      expect(child_entity.raw_data_provenances.count).to eq(1)
      expect(statement.raw_data_provenances.count).to eq(1)
    end
  end
end
