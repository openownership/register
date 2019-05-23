require 'rails_helper'

RSpec.describe OpenCorporatesUpdateWorker do
  let(:entity_resolver) { instance_double('EntityResolver') }
  let(:index_entity_service) { instance_double('IndexEntityService') }
  let!(:entity) { create(:legal_entity) }

  before do
    allow(entity_resolver).to receive(:resolve!).and_return(nil)
    allow(EntityResolver).to receive(:new).and_return(entity_resolver)

    allow(index_entity_service).to receive(:index).and_return(nil)
    allow(IndexEntityService).to receive(:new).and_return(index_entity_service)
  end

  subject { OpenCorporatesUpdateWorker.new.perform(entity.id) }

  it 'resolves entities with OpenCorporates' do
    expect(entity_resolver).to(receive(:resolve!)).with(entity)
    subject
  end

  it 'updates any details which have changed' do
    allow(entity_resolver).to receive(:resolve!).with(entity) do |e|
      e.name = 'Updated'
      e.oc_updated_at = Time.zone.now
    end
    subject
    expect(entity.reload.name).to eq 'Updated'
  end

  it 'updates the entity in ElasticSearch' do
    allow(entity_resolver).to receive(:resolve!).with(entity) do |e|
      e.name = 'Updated'
      e.oc_updated_at = Time.zone.now
    end
    expect(IndexEntityService)
      .to(receive(:new))
      .with(entity)
      .and_return(index_entity_service)
    expect(index_entity_service).to receive(:index)
    subject
  end

  it "only updates last_resolved_at when OpenCorporates' data hasn't changed" do
    allow(entity_resolver).to receive(:resolve!).with(entity) do |e|
      # We change the name so that we can check it's ignored by the
      # worker when oc_updated_at doesn't change
      e.name = 'Updated'
      # Note we also don't set last_resolved_at, because the worker should
      # touch it separately to avoid having to do an upsert/merge/index
    end
    expect(index_entity_service).not_to receive(:index)
    expect { subject }.not_to change { entity.reload.name }
    # Check it touches the last_resolved_at date
    expect(entity.reload.last_resolved_at).to be_within(1.second).of(Time.zone.now)
  end

  it 'merges entities that become duplicates after updating' do
    duplicate_entity = create(:legal_entity)
    allow(entity_resolver).to receive(:resolve!).with(duplicate_entity) do |e|
      # Simulating the situation where OC has new data which allows us to
      # identify a company, and it turns out to be an existing one.
      e.identifiers << entity.identifiers.first
      e.name = entity.name
      e.oc_updated_at = Time.zone.now
      e.last_resolved_at = Time.zone.now
    end

    expect(IndexEntityService)
      .to(receive(:new))
      .with(duplicate_entity)
      .and_return(index_entity_service)
    expect(index_entity_service).to receive(:delete)

    expect do
      OpenCorporatesUpdateWorker.new.perform(duplicate_entity.id)
    end.to change { Entity.count }.by(-1)

    expect(Entity.where(id: duplicate_entity.id)).not_to exist
    expect(entity.reload.oc_updated_at).to be_within(1.second).of(Time.zone.now)
    expect(entity.reload.last_resolved_at).to be_within(1.second).of(Time.zone.now)
  end

  it 'logs and then skips entities which have merge issues' do
    # Create a merge issue by giving two entities different OC identifiers and
    # then simulating an update which adds another identifier linking them
    # together.
    entity.add_oc_identifier(jurisdiction_code: 'gb', company_number: '1234')
    entity.save!
    duplicate_entity = create(:legal_entity)
    duplicate_entity.add_oc_identifier(jurisdiction_code: 'gb', company_number: '5678')
    duplicate_entity.save!

    allow(entity_resolver).to receive(:resolve!).with(duplicate_entity) do |e|
      e.identifiers << entity.identifiers.first
      e.name = entity.name
      e.oc_updated_at = Time.zone.now
      e.last_resolved_at = Time.zone.now
    end

    expected_message = "OpenCorporatesUpdateWorker Failed to handle a " \
                       "required entity merge as a potentially bad merge has " \
                       "been detected and stopped: differing OC identifiers " \
                       "detected - will not complete the update of " \
                       "#{duplicate_entity.id}"
    expect(Rails.logger).to receive(:warn).with(expected_message)
    expect do
      OpenCorporatesUpdateWorker.new.perform(duplicate_entity.id)
    end.not_to change { Entity.count }
  end
end
