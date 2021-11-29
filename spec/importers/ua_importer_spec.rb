require 'rails_helper'

RSpec.describe UaImporter do
  let(:entity_resolver) { instance_double('EntityResolver') }
  let(:index_entity_service) { instance_double('IndexEntityService') }
  let(:source_url) { 'https://data.gov.ua/dataset/1c7f3815-3259-45e0-bdf1-64dca07ddc10' }
  let(:source_name) { 'Ukraine Consolidated State Registry (Edinyy Derzhavnyj Reestr [EDR])' }
  let(:document_id) { 'Ukraine EDR' }
  let(:retrieved_at) { Time.zone.local(2017, 2, 3, 4, 5, 6) }

  subject do
    UaImporter.new(
      entity_resolver: entity_resolver,
      source_url: source_url,
      source_name: source_name,
      document_id: document_id,
      retrieved_at: retrieved_at,
    )
  end

  describe '#process' do
    let(:fixture) { 'ua_extracted_bo_data.json' }

    let(:company_number) { '12345678' }
    let(:company_name) { 'Example Українська Company' }
    let(:company_address) { '12345, Example Region, Example City, Example District, Example Street, Building 1, Apartment 1' }

    let(:bo_name) { 'вася пупкин' }
    let(:bo_country_of_residence) { 'україна' }
    let(:bo_address) { '12345, Example Region, Example City, Example District, Example Street, Building 1, Apartment 1' }

    before do
      allow(entity_resolver).to receive(:resolve!)
      allow(IndexEntityService).to receive(:new).and_return(index_entity_service)
      allow(index_entity_service).to receive(:index)
    end

    it 'resolves the child company' do
      subject.parse(file_fixture(fixture))
      expect(entity_resolver).to have_received(:resolve!).with(
        having_attributes(
          jurisdiction_code: 'ua',
          company_number: company_number,
          name: company_name,
        ),
      )
    end

    it 'creates the child company entity' do
      subject.parse(file_fixture(fixture))
      entity = Entity.find_by(name: company_name)
      expect(entity.identifiers.first).to eq(
        'document_id' => document_id,
        'company_number' => company_number,
      )
      expect(entity.type).to eq(Entity::Types::LEGAL_ENTITY)
      expect(entity.jurisdiction_code).to eq('ua')
      expect(entity.company_number).to eq(company_number)
      expect(entity.name).to eq(company_name)
      expect(entity.address).to eq(company_address)
    end

    it 'creates a parent entity for the beneficial owner' do
      subject.parse(file_fixture(fixture))
      entity = Entity.find_by(name: bo_name)
      expect(entity.type).to eq(Entity::Types::NATURAL_PERSON)
      expect(entity.identifiers.first).to eq(
        'document_id' => document_id,
        'company_number' => company_number,
        'beneficial_owner_id' => bo_name,
      )
      expect(entity.name).to eq(bo_name)
      expect(entity.country_of_residence).to eq(bo_country_of_residence)
      expect(entity.address).to eq(bo_address)
    end

    it 'creates a relationship between the child and parent entities' do
      subject.parse(file_fixture(fixture))
      expect(Relationship.count).to eq(1)

      child_entity = Entity.find_by(name: company_name)
      parent_entity = Entity.find_by(name: bo_name)

      relationship = Relationship.find_by(source: parent_entity, target: child_entity)
      expect(relationship._id).to eq(
        'document_id' => document_id,
        'company_number' => company_number,
        'beneficial_owner_id' => bo_name,
      )
      expect(relationship.provenance.source_url).to eq(source_url)
      expect(relationship.provenance.source_name).to eq(source_name)
      expect(relationship.provenance.retrieved_at).to eq(retrieved_at)
      expect(relationship.provenance.imported_at).to be_a(Time)
    end

    it 'creates relationships idempotently' do
      file = file_fixture(fixture)
      subject.parse(file)
      expect { subject.parse(file) }.not_to change { Relationship.count }
    end

    it 'indexes all the entities' do
      subject.parse(file_fixture(fixture))
      expect(IndexEntityService).to(
        have_received(:new)
        .with(having_attributes(name: company_name)),
      )
      expect(IndexEntityService).to(
        have_received(:new)
        .with(having_attributes(name: bo_name)),
      )
    end
  end
end
