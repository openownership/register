require 'rails_helper'

RSpec.describe EntityMerger do
  let(:index_entity_service) { instance_double('IndexEntityService') }

  subject { described_class.new(to_remove, to_keep) }

  let!(:relationship_1) { create :relationship, source: to_remove }
  let!(:relationship_2) { create :relationship, target: to_remove }
  let!(:statement) { create :statement, entity: to_remove }

  let!(:other_entity) { create :legal_entity }
  let!(:other_relationship_1) { create :relationship, source: other_entity }
  let!(:other_relationship_2) { create :relationship, target: other_entity }
  let!(:other_statement) { create :statement, entity: other_entity }

  before do
    allow(IndexEntityService).to receive(:new).with(to_remove).and_return(index_entity_service)
    allow(IndexEntityService).to receive(:new).with(to_keep).and_return(index_entity_service)
  end

  def expect_not_merged
    expect(Entity.find(to_remove._id)).to eq to_remove
    expect(Entity.find(to_keep._id)).to eq to_keep

    expect(Relationship.find(relationship_1._id).source).to eq to_remove
    expect(Relationship.find(relationship_2._id).target).to eq to_remove
    expect(Statement.find(statement._id).entity).to eq to_remove

    expect_others_not_changed
  end

  def expect_merged(merged_identifiers, merged_fields)
    expect(Entity.where(id: to_remove._id).exists?).to be false
    expect(Entity.where(id: to_keep._id).exists?).to be true

    merged = Entity.find(to_keep._id)
    expect(merged.identifiers).to match_array merged_identifiers
    merged_fields.each do |(k, v)|
      expect(merged[k]).to eq v
    end

    expect(Relationship.find(relationship_1._id).source).to eq to_keep
    expect(Relationship.find(relationship_2._id).target).to eq to_keep
    expect(Statement.find(statement._id).entity).to eq to_keep

    expect_others_not_changed
  end

  def expect_others_not_changed
    expect(Entity.find(other_entity._id)).to eq other_entity

    expect(Relationship.find(other_relationship_1._id).source).to eq other_entity
    expect(Relationship.find(other_relationship_2._id).target).to eq other_entity
    expect(Statement.find(other_statement._id).entity).to eq other_entity
  end

  def set_up_search_index_not_updated_expectations
    expect(index_entity_service).to receive(:delete).never
    expect(index_entity_service).to receive(:index).never
  end

  def set_up_search_index_updated_expectations
    expect(index_entity_service).to receive(:delete)
    expect(index_entity_service).to receive(:index)
  end

  context 'with the same entity for both to_remove and to_keep' do
    let(:entity) { create :legal_entity }
    let(:to_remove) { entity }
    let(:to_keep) { entity }

    let :error_message do
      'Trying to merge the same entity'
    end

    it 'should raise an error when trying to merge and not merge anything' do
      set_up_search_index_not_updated_expectations
      expect { subject.call }.to raise_error(error_message)
      expect_not_merged
    end
  end

  context 'with different entities of different types' do
    let(:to_remove) { create :legal_entity }
    let(:to_keep) { create :natural_person }

    let :error_message do
      "to_remove entity type '#{to_remove.type}' does not match to_keep entity type '#{to_keep.type}' - cannot merge"
    end

    it 'should raise an error when trying to merge and not merge anything' do
      set_up_search_index_not_updated_expectations
      expect { subject.call }.to raise_error(error_message)
      expect_not_merged
    end
  end

  context 'with different entities of the same type' do
    context 'when only one entity has an OC identifier' do
      let(:to_remove_name) { 'Foo Ltd.' }

      let(:to_remove_oc_identifier) do
        Entity.build_oc_identifier(
          jurisdiction_code: 'gb',
          company_number: 1234,
        )
      end

      let!(:to_remove) { create :legal_entity, identifiers: [to_remove_oc_identifier], name: to_remove_name, address: '123 street' }

      let!(:to_keep) { create :legal_entity, name: nil, address: '345 street' }

      let! :merged_identifiers do
        to_remove.identifiers + to_keep.identifiers
      end

      let! :merged_fields do
        (Entity.fields.keys - EntityMerger::PROTECTED_FIELDS).each_with_object({}) do |f, h|
          h[f] = to_keep[f]
        end.merge(
          'name' => to_remove_name,
        )
      end

      it 'should remove the to_remove entity and merge certain bits of data into the to_keep entity and update all relevant references to the to_remove entity' do
        set_up_search_index_updated_expectations
        merged_entity = subject.call
        expect(merged_entity).to eq to_keep
        expect_merged(merged_identifiers, merged_fields)
      end
    end

    context 'when the two entities have differing OC identifiers' do
      let(:to_remove_oc_identifier) do
        Entity.build_oc_identifier(
          jurisdiction_code: 'gb',
          company_number: 1234,
        )
      end

      let(:to_keep_oc_identifier) do
        Entity.build_oc_identifier(
          jurisdiction_code: 'pl',
          company_number: 1234,
        )
      end

      let!(:to_remove) { create :legal_entity, identifiers: [to_remove_oc_identifier] }

      let!(:to_keep) { create :legal_entity, identifiers: [to_keep_oc_identifier] }

      it 'should raise an error when trying to merge and not merge anything' do
        set_up_search_index_not_updated_expectations
        expect { subject.call }.to raise_error(PotentiallyBadEntityMergeDetectedAndStopped, 'differing OC identifiers detected')
        expect_not_merged
      end
    end
  end
end
