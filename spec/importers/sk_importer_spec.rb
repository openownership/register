require 'rails_helper'
require 'support/fixture_helpers'

RSpec.describe SkImporter do
  let(:entity_resolver) { instance_double('EntityResolver') }
  let(:sk_client) { instance_double('SkClient') }
  let(:index_entity_service) { instance_double('IndexEntityService') }
  let(:google_client) { instance_double('GoogleGeocoderClient') }
  let(:data_source) { create(:sk_data_source) }
  let(:import) { create(:import, data_source: data_source) }
  let(:retrieved_at) { Time.zone.local(2011, 2, 3, 4, 5, 6) }

  subject do
    SkImporter.new(entity_resolver: entity_resolver, client: sk_client, geocoder_client: google_client).tap do |importer|
      importer.import = import
      importer.retrieved_at = retrieved_at
    end
  end

  def paginated_parents_data(count)
    raw_data = sk_json_fixture('sk_bo_datum.json')
    parent_record = raw_data['KonecniUzivateliaVyhod'].first
    generated_parents = count.times.map do |i|
      parent = parent_record.dup
      parent['Id'] = i
      parent['Priezvisko'] = "Person #{i}"
      parent
    end
    raw_data['KonecniUzivateliaVyhod'] = generated_parents
  end

  describe '#process' do
    before do
      allow(entity_resolver).to receive(:resolve!)

      allow(IndexEntityService).to receive(:new).and_return(index_entity_service)
      allow(index_entity_service).to receive(:index)
      allow(google_client).to receive(:jurisdiction).and_return('sk')
    end

    it 'resolves the child company' do
      subject.process(sk_json_fixture('sk_bo_datum.json'))

      expect(entity_resolver).to have_received(:resolve!).with(having_attributes(
        jurisdiction_code: 'sk',
        company_number: '1234567',
        name: 'Example Slovak Company',
      ))
    end

    it "gets the child company's jurisdiction from geocoding the address" do
      subject.process(sk_json_fixture('sk_bo_datum.json'))
      address = '1234/1 Example Street, Example Place, 12345'
      expect(google_client).to have_received(:jurisdiction).with(address)
    end

    it 'creates the child company entity' do
      subject.process(sk_json_fixture('sk_bo_datum.json'))

      entity = Entity.find_by(name: 'Example Slovak Company')

      expect(entity.identifiers.first).to eq(
        'document_id' => data_source.document_id,
        'company_number' => '1234567',
      )
      expect(entity.type).to eq(Entity::Types::LEGAL_ENTITY)
      expect(entity.company_number).to eq('1234567')
      expect(entity.jurisdiction_code).to eq('sk')
    end

    it 'prefers the current child company entity if there is more than one' do
      # Create a file with one record that's got a valid-to date, i.e. is not
      # current, and a new one that is, with some updated details
      raw_data = JSON.parse file_fixture('sk_bo_datum.json').read
      current_child_entity = raw_data['PartneriVerejnehoSektora'].first.dup
      raw_data['PartneriVerejnehoSektora'].first['PlatnostDo'] = "2015-01-02T00:00:00+01:00"
      current_child_entity['PlatnostOd'] = "2015-01-02T00:00:00+01:00"
      current_child_entity['ObchodneMeno'] = "Updated Slovak Company"
      raw_data['PartneriVerejnehoSektora'] << current_child_entity

      record = create(:raw_data_record, raw_data: raw_data.to_json)

      subject.process(record)

      entity = Entity.find_by(name: 'Updated Slovak Company')

      expect(entity.identifiers.first).to eq(
        'document_id' => data_source.document_id,
        'company_number' => '1234567',
      )
      expect(entity.type).to eq(Entity::Types::LEGAL_ENTITY)
    end

    it 'chooses the most recently ended child company if none are current' do
      # Create a file with two records that have a valid-to date, i.e. are not
      # current, but one newer than the other
      raw_data = JSON.parse file_fixture('sk_bo_datum.json').read
      current_child_entity = raw_data['PartneriVerejnehoSektora'].first.dup
      raw_data['PartneriVerejnehoSektora'].first['PlatnostDo'] = "2015-01-02T00:00:00+01:00"
      current_child_entity['PlatnostOd'] = "2015-01-02T00:00:00+01:00"
      current_child_entity['PlatnostDo'] = "2015-01-03T00:00:00+01:00"
      current_child_entity['ObchodneMeno'] = "Updated Slovak Company"
      raw_data['PartneriVerejnehoSektora'] << current_child_entity

      record = create(:raw_data_record, raw_data: raw_data.to_json)

      subject.process(record)

      entity = Entity.find_by(name: 'Updated Slovak Company')

      expect(entity.identifiers.first).to eq(
        'document_id' => data_source.document_id,
        'company_number' => '1234567',
      )
      expect(entity.type).to eq(Entity::Types::LEGAL_ENTITY)
    end

    it 'skips records when the child entity has no company name' do
      # See OO-251, some results from the api have no company name (they have
      # first name and last name instead) and we're not sure what to about them
      # yet so we just skip over them.
      raw_data = JSON.parse file_fixture('sk_bo_datum.json').read
      raw_data['PartneriVerejnehoSektora'].first['ObchodneMeno'] = nil
      raw_data['PartneriVerejnehoSektora'].first['Meno'] = "Example"
      raw_data['PartneriVerejnehoSektora'].first['Priezvisko'] = "Company Person"

      record = create(:raw_data_record, raw_data: raw_data.to_json)

      expect do
        subject.process(record)
      end.not_to change { Entity.count }
    end

    it 'leaves the company_number blank for foreign child entities' do
      # All entities have an SK Ico number, but this isn't a useful company
      # number for foreign companies, so we don't record it as such.
      allow(google_client).to receive(:jurisdiction).and_return('gb')

      subject.process(sk_json_fixture('sk_bo_datum.json'))
      entity = Entity.find_by(name: 'Example Slovak Company')

      expect(entity.jurisdiction_code).to eq('gb')
      expect(entity.company_number).to be_nil
    end

    it 'reports an error when child entities are paginated' do
      raw_data = JSON.parse file_fixture('sk_bo_datum.json').read
      raw_data["PartneriVerejnehoSektora@odata.nextLink"] = "https://rpvs.gov.sk/OpenData/Partneri(1)/PartneriVerejnehoSektora?$skip=20"

      record = create(:raw_data_record, raw_data: raw_data.to_json)

      expect(Rollbar).to receive(:error).with("SK record Id: 1 has paginated child entities (PartneriVerejnehoSektora)")

      subject.process(record)
    end

    it 'creates a parent entity for each beneficial owner' do
      subject.process(sk_json_fixture('sk_bo_datum.json'))

      entity = Entity.find_by(name: 'Example Person 1')

      expect(entity.identifiers.first).to eq(
        'document_id' => data_source.document_id,
        'beneficial_owner_id' => 1,
      )
      expect(entity.type).to eq(Entity::Types::NATURAL_PERSON)
      expect(entity.nationality).to eq('SK')
      expect(entity.address).to eq('1234/1 Example Street, Example Place, 12345')
      expect(entity.dob).to eq(ISO8601::Date.new('1950-01-01'))

      entity = Entity.find_by(name: 'Example Person 2')

      expect(entity.identifiers.first).to eq(
        'document_id' => data_source.document_id,
        'beneficial_owner_id' => 2,
      )
      expect(entity.type).to eq(Entity::Types::NATURAL_PERSON)
      expect(entity.nationality).to eq('SK')
      expect(entity.address).to eq('1234/2 Example Street, Example Place, 12345')
    end

    it 'indexes all the entities' do
      expect(IndexEntityService).to receive(:new).with(having_attributes(
        name: 'Example Slovak Company',
      ))
      expect(IndexEntityService).to receive(:new).with(having_attributes(
        name: 'Example Person 1',
      ))
      expect(IndexEntityService).to receive(:new).with(having_attributes(
        name: 'Example Person 2',
      ))

      subject.process(sk_json_fixture('sk_bo_datum.json'))
    end

    it 'loads all parent entities when the list is paginated' do
      # Add a pagination link to trigger us getting a full company
      # record
      raw_data = JSON.parse file_fixture('sk_bo_datum.json').read
      raw_data["KonecniUzivateliaVyhod@odata.nextLink"] = "https://rpvs.gov.sk/OpenData/Partneri(1)/KonecniUzivateliaVyhod?$skip=20"

      record = create(:raw_data_record, raw_data: raw_data.to_json)

      company_record = JSON.parse file_fixture('sk_company_datum.json').read
      expect(sk_client).to receive(:company_record).with(1).and_return(company_record)

      subject.process(record)

      child_entity = Entity.find_by(name: 'Example Slovak Company')

      expect(child_entity.relationships_as_target.count).to eq(3)
    end

    it 'creates relationships between child and parent entities' do
      subject.process(sk_json_fixture('sk_bo_datum.json'))

      expect(Relationship.count).to eq(2)

      child_entity = Entity.find_by(name: 'Example Slovak Company')

      ['Example Person 1', 'Example Person 2'].each do |name|
        parent_entity = Entity.find_by(name: name)

        relationship = Relationship.find_by(source: parent_entity, target: child_entity)

        expect(relationship.sample_date).to eq(ISO8601::Date.new('2015-01-01'))
        expect(relationship.started_date).to eq(ISO8601::Date.new('2015-01-01'))
        expect(relationship.ended_date).to be_nil
        expect(relationship.provenance.source_url).to eq(import.data_source.url)
        expect(relationship.provenance.source_name).to eq(import.data_source.name)
        expect(relationship.provenance.retrieved_at).to eq(retrieved_at)
        expect(relationship.provenance.imported_at).to be_a(Time)
      end
    end

    it 'creates relationships idempotently' do
      record = sk_json_fixture('sk_bo_datum.json')

      subject.process(record)

      expect { subject.process(record) }.not_to change { Relationship.count }
    end

    it 'includes beneficial owner data which is no longer valid' do
      raw_data = JSON.parse file_fixture('sk_bo_datum.json').read

      raw_data['KonecniUzivateliaVyhod'].each do |item|
        item['PlatnostDo'] = '2015-01-02T00:00:00+01:00'
      end
      record = create(:raw_data_record, raw_data: raw_data.to_json)

      expect { subject.process(record) }.to change { Relationship.count }.by(2)

      child_entity = Entity.find_by(name: 'Example Slovak Company')
      ['Example Person 1', 'Example Person 2'].each do |name|
        parent_entity = Entity.find_by(name: name)
        relationship = Relationship.find_by(source: parent_entity, target: child_entity)

        expect(relationship.ended_date).to eq(ISO8601::Date.new('2015-01-02'))
      end
    end

    context "when multiple entries match the child entity identifiers" do
      let(:sk_identifier) do
        {
          'document_id' => data_source.document_id,
          'company_number' => '1234567',
        }
      end

      let(:oc_identifier) do
        {
          'jurisdiction_code' => 'sk',
          'company_number' => '1234567',
        }
      end

      let!(:sk_existing_entity) { create(:legal_entity, identifiers: [sk_identifier]) }
      let!(:oc_existing_entity) { create(:legal_entity, identifiers: [oc_identifier]) }

      it 'merges the duplicate entities into one' do
        expect(entity_resolver).to(
          receive(:resolve!)
          .with(
            having_attributes(
              jurisdiction_code: 'sk',
              company_number: '1234567',
            ),
          ) { |e| e.identifiers << oc_identifier },
        )
        # The merge process should remove one entity from elasticsearch
        expect(index_entity_service).to receive(:delete)

        subject.process(sk_json_fixture('sk_bo_datum.json'))

        entity = Entity.find_by(name: 'Example Slovak Company')

        # This entity should be deleted because it doesn't have an OC id, so it
        # loses the battle in the merge process
        expect(Entity.where(id: sk_existing_entity.id)).to be_empty
        expect(oc_existing_entity.reload).to eq(entity)

        expect(entity.identifiers).to match_array([sk_identifier, oc_identifier])
      end
    end
  end

  describe '#process_records' do
    before do
      allow(entity_resolver).to receive(:resolve!)

      allow(IndexEntityService).to receive(:new).and_return(index_entity_service)
      allow(index_entity_service).to receive(:index)
      allow(google_client).to receive(:jurisdiction).and_return('sk')
    end

    it 'creates RawDataProvenance records for entities and relationships' do
      records = sk_json_fixture('sk_bo_data.json')

      expect do
        subject.process_records(records)
      end.to change { RawDataProvenance.count }.from(0).to(5)

      company = Entity.find_by(name: 'Example Slovak Company')
      person1 = Entity.find_by(name: 'Example Person 1')
      person2 = Entity.find_by(name: 'Example Person 2')

      person1_relationship = Relationship.find_by(source: person1, target: company)
      person2_relationship = Relationship.find_by(source: person2, target: company)

      expect(company.raw_data_provenances.count).to eq(1)

      expect(person1.raw_data_provenances.count).to eq(1)
      expect(person2.raw_data_provenances.count).to eq(1)

      expect(person1_relationship.raw_data_provenances.count).to eq(1)
      expect(person2_relationship.raw_data_provenances.count).to eq(1)
    end

    it 'creates RawDataProvenance records for entities with paginated entities' do
      raw_data = JSON.parse file_fixture('sk_bo_datum.json').read
      raw_data["KonecniUzivateliaVyhod@odata.nextLink"] = "https://rpvs.gov.sk/OpenData/Partneri(1)/KonecniUzivateliaVyhod?$skip=20"

      record = create(:raw_data_record, raw_data: raw_data.to_json)

      company_record = JSON.parse file_fixture('sk_company_datum.json').read
      expect(sk_client).to receive(:company_record).with(1).and_return(company_record)

      subject.process_records([record])

      child_entity = Entity.find_by(name: 'Example Slovak Company')

      child_entity.relationships_as_target.each do |parent_entity|
        expect(parent_entity.raw_data_provenances.count).to eq(1)
      end
    end
  end
end
