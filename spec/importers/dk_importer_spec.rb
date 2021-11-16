require 'rails_helper'
require 'support/fixture_helpers'

RSpec.describe DkImporter do
  let(:entity_resolver) { instance_double('EntityResolver') }
  let(:index_entity_service) { instance_double('IndexEntityService') }
  let(:data_source) { create(:dk_data_source) }
  let(:import) { create(:import, data_source: data_source) }
  let(:retrieved_at) { Time.zone.local(2011, 2, 3, 4, 5, 6) }

  subject do
    DkImporter.new(entity_resolver: entity_resolver).tap do |importer|
      importer.import = import
      importer.retrieved_at = retrieved_at
    end
  end

  describe '#process' do
    before do
      allow(entity_resolver).to receive(:resolve!)

      allow(IndexEntityService).to receive(:new).and_return(index_entity_service)
      allow(index_entity_service).to receive(:index)
    end

    def expect_provenance(relationship)
      expect(relationship.provenance.source_url).to eq(data_source.url)
      expect(relationship.provenance.source_name).to eq(data_source.name)
      expect(relationship.provenance.retrieved_at).to eq(retrieved_at)
      expect(relationship.provenance.imported_at).to be_a(Time)
    end

    context 'for a record with no real owners' do
      before do
        # Has share ownerships and directorships, but no 'Reel ejer' data
        @record = dk_json_fixture('dk_bo_datum_no_real_owners.json')
        subject.process(@record)
      end

      it 'does not import any data' do
        expect(entity_resolver).to receive(:resolve!).never
        expect(Entity.count).to be 0
        expect(Relationship.count).to be 0
      end
    end

    context 'for a record with real owners - simple' do
      before do
        @record = dk_json_fixture('dk_bo_datum_with_real_owners_simple.json')
        subject.process(@record)
      end

      it 'creates the parent entity' do
        expect(Entity.natural_persons.count).to be 1

        entity = Entity.natural_persons.first
        expect(entity.identifiers).to eq(
          [
            {
              'document_id' => data_source.document_id,
              'beneficial_owner_id' => '2',
            },
          ],
        )
        expect(entity.type).to eq(Entity::Types::NATURAL_PERSON)
        expect(entity.name).to eq('Danish Person 2')
        expect(entity.country_of_residence).to eq('DK')
        expect(entity.address).to eq('Example Vej 1, 1, Example Town, 4567')
      end

      it 'resolves the one child company' do
        expect(entity_resolver).to have_received(:resolve!).with(
          having_attributes(
            jurisdiction_code: 'dk',
            company_number: '13141516',
            name: 'Danish Company 3',
          ),
        )
      end

      it 'creates the one child company' do
        expect(Entity.legal_entities.count).to be 1

        entity = Entity.legal_entities.first
        expect(entity.identifiers).to eq(
          [
            {
              'document_id' => data_source.document_id,
              'company_number' => '13141516',
            },
          ],
        )
        expect(entity.name).to eq 'Danish Company 3'
        expect(entity.jurisdiction_code).to eq 'dk'
        expect(entity.company_number).to eq '13141516'
      end

      it 'indexes all the entities' do
        expect(IndexEntityService).to have_received(:new).with(
          having_attributes(
            name: 'Danish Person 2',
          ),
        )
        expect(IndexEntityService).to have_received(:new).with(
          having_attributes(
            name: 'Danish Company 3',
          ),
        )
      end

      it 'creates a relationship between the parent entity and the child entity' do
        expect(Relationship.count).to be 1

        relationship = Relationship.first
        expect(relationship._id).to eq(
          'document_id' => data_source.document_id,
          'beneficial_owner_id' => '2',
          'company_number' => '13141516',
        )
        expect(relationship.target).to eq(Entity.legal_entities.first)
        expect(relationship.source).to eq(Entity.natural_persons.first)
        expect(relationship.interests).to match_array(
          [
            { 'type' => 'shareholding', 'share_min' => 100.0, 'share_max' => 100.0 },
            { 'type' => 'voting-rights', 'share_min' => 100.0, 'share_max' => 100.0 },
          ],
        )
        expect(relationship.started_date).to eq(ISO8601::Date.new('2015-01-01'))
        expect(relationship.ended_date).to be nil
        expect(relationship.sample_date).to eq(ISO8601::Date.new('2015-01-01'))
        expect(relationship.is_indirect).to be false
        expect_provenance(relationship)
      end

      it 'creates relationships idempotently' do
        expect { subject.process(@record) }.not_to change { Relationship.count }
      end
    end

    context 'for a record with real owners - complex' do
      before do
        @record = dk_json_fixture('dk_bo_datum_with_real_owners_complex.json')
        subject.process(@record)
      end

      it 'creates the parent entity' do
        expect(Entity.natural_persons.count).to be 1

        entity = Entity.natural_persons.first
        expect(entity.identifiers).to eq(
          [
            {
              'document_id' => data_source.document_id,
              'beneficial_owner_id' => '1',
            },
          ],
        )
        expect(entity.type).to eq(Entity::Types::NATURAL_PERSON)
        expect(entity.name).to eq('Danish Person 1')
        expect(entity.country_of_residence).to eq('DK')
        expect(entity.address).to eq('Example Vej 1, Example Town, 1234')
      end

      it 'resolves all child companies' do
        expect(entity_resolver).to have_received(:resolve!).with(
          having_attributes(
            jurisdiction_code: 'dk',
            company_number: '1234567',
            name: 'Renamed Danish Company 1',
          ),
        )

        expect(entity_resolver).to have_received(:resolve!).with(
          having_attributes(
            jurisdiction_code: 'dk',
            company_number: '89101112',
            name: 'Danish Company 2',
          ),
        )
      end

      it 'creates all child companies' do
        expect(Entity.legal_entities.count).to be 2

        entity = Entity.legal_entities.find_by(name: 'Renamed Danish Company 1')
        expect(entity.identifiers).to eq(
          [
            {
              'document_id' => data_source.document_id,
              'company_number' => '1234567',
            },
          ],
        )
        expect(entity.jurisdiction_code).to eq 'dk'
        expect(entity.company_number).to eq '1234567'

        entity = Entity.legal_entities.find_by(name: 'Danish Company 2')
        expect(entity.identifiers).to eq(
          [
            {
              'document_id' => data_source.document_id,
              'company_number' => '89101112',
            },
          ],
        )
        expect(entity.jurisdiction_code).to eq 'dk'
        expect(entity.company_number).to eq '89101112'
      end

      it 'indexes all entities' do
        expect(IndexEntityService).to have_received(:new).with(
          having_attributes(
            name: 'Danish Person 1',
          ),
        )
        expect(IndexEntityService).to have_received(:new).with(
          having_attributes(
            name: 'Renamed Danish Company 1',
          ),
        )
        expect(IndexEntityService).to have_received(:new).with(
          having_attributes(
            name: 'Danish Company 2',
          ),
        )
      end

      it 'creates relationships between the parent entity and all child entities' do
        expect(Relationship.count).to be 2

        parent = Entity.natural_persons.first

        entity = Entity.legal_entities.find_by(name: 'Renamed Danish Company 1')
        expect(entity.relationships_as_target.count).to eq 1
        relationship = entity.relationships_as_target.first
        expect(relationship._id).to eq(
          'document_id' => data_source.document_id,
          'beneficial_owner_id' => '1',
          'company_number' => '1234567',
        )
        expect(relationship.target).to eq(entity)
        expect(relationship.source).to eq(parent)
        expect(relationship.interests).to match_array(
          [
            { 'type' => 'shareholding', 'share_min' => 50.0, 'share_max' => 50.0 },
            { 'type' => 'voting-rights', 'share_min' => 50.0, 'share_max' => 50.0 },
          ],
        )
        expect(relationship.started_date).to eq(ISO8601::Date.new('2015-01-01'))
        expect(relationship.ended_date).to be nil
        expect(relationship.sample_date).to eq(ISO8601::Date.new('2015-01-02'))
        expect(relationship.is_indirect).to be false
        expect_provenance(relationship)

        entity = Entity.legal_entities.find_by(name: 'Danish Company 2')
        expect(entity.relationships_as_target.count).to eq 1
        relationship = entity.relationships_as_target.first
        expect(relationship._id).to eq(
          'document_id' => data_source.document_id,
          'beneficial_owner_id' => '1',
          'company_number' => '89101112',
        )
        expect(relationship.target).to eq(entity)
        expect(relationship.source).to eq(parent)
        expect(relationship.interests).to match_array(
          [
            { 'type' => 'shareholding', 'share_min' => 50.0, 'share_max' => 50.0 },
            { 'type' => 'voting-rights', 'share_min' => 50.0, 'share_max' => 50.0 },
          ],
        )
        expect(relationship.started_date).to eq(ISO8601::Date.new('2015-01-01'))
        expect(relationship.ended_date).to be nil
        expect(relationship.sample_date).to eq(ISO8601::Date.new('2015-01-01'))
        expect(relationship.is_indirect).to be true
        expect_provenance(relationship)
      end

      it 'creates relationships idempotently' do
        expect { subject.process(@record) }.not_to change { Relationship.count }
      end
    end
  end

  describe '#process_records' do
    before do
      allow(entity_resolver).to receive(:resolve!)

      allow(IndexEntityService).to receive(:new).and_return(index_entity_service)
      allow(index_entity_service).to receive(:index)
    end

    it 'creates RawDataProvenance records for entities and relationships' do
      record = dk_json_fixture('dk_bo_datum_with_real_owners_complex.json')

      expect do
        subject.process_records([record])
      end.to change { RawDataProvenance.count }.from(0).to(5)

      parent_entity = Entity.find_by(name: 'Danish Person 1')
      child_entities = [
        'Renamed Danish Company 1',
        'Danish Company 2',
      ].map { |n| Entity.find_by(name: n) }
      relationships = child_entities.map { |e| Relationship.find_by(target: e) }

      expect(parent_entity.raw_data_provenances.count).to eq(1)
      child_entities.each { |e| expect(e.raw_data_provenances.count).to eq(1) }
      relationships.each { |r| expect(r.raw_data_provenances.count).to eq(1) }
    end
  end
end
