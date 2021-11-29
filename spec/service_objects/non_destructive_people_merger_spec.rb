require 'rails_helper'

RSpec.describe NonDestructivePeopleMerger do
  let(:person1) { create(:natural_person) }
  let(:person2) { create(:natural_person) }
  let(:index_entity_service) { instance_double(IndexEntityService) }

  before do
    allow(IndexEntityService).to receive(:new).and_return(index_entity_service)
  end

  context "when one of the entities is not a person" do
    let(:company) { create(:legal_entity) }

    it "raises an error and does not merge them" do
      person1_count_before = person1.merged_entities.count
      company_count_before = company.merged_entities.count

      expect do
        NonDestructivePeopleMerger.new(company, person1).call
      end.to raise_error('to_merge is not a person')

      expect do
        NonDestructivePeopleMerger.new(person1, company).call
      end.to raise_error('to_keep is not a person')

      expect(person1.merged_entities.count).to eq person1_count_before
      expect(company.merged_entities.count).to eq company_count_before
    end
  end

  context "when the people are the same" do
    it "raises an error and does not merge them" do
      merged_count_before = person1.merged_entities.count

      expect do
        NonDestructivePeopleMerger.new(person1, person1).call
      end.to raise_error('Trying to merge the same entity')

      expect(person1.merged_entities.count).to eq merged_count_before
    end
  end

  context "when the people are mergeable" do
    subject { NonDestructivePeopleMerger.new(person2, person1).call }

    it "adds the to_merge person to the to_keep person's merged_entities" do
      allow(index_entity_service).to receive(:delete)
      subject
      expect(person1.reload.merged_entities).to match_array [person2]
    end

    it "makes the to_keep person the to_merge person's master_entity" do
      allow(index_entity_service).to receive(:delete)
      subject
      expect(person2.reload.master_entity).to eq person1
    end

    it "sets merged_entities_count on the to_keep entity" do
      allow(index_entity_service).to receive(:delete)
      subject
      expect(person1.reload.merged_entities_count).to eq(1)
    end

    it "deletes the to_merge person from Elasticsearch" do
      expect(index_entity_service).to receive(:delete)
      subject
    end
  end

  context "when the people to merge already have merged people" do
    let!(:person3) { create(:natural_person, master_entity: person2) }
    let!(:person4) { create(:natural_person, master_entity: person3) }

    subject { NonDestructivePeopleMerger.new(person2, person1).call }

    it "adds all of the entities to the to_keep person's merged_entities" do
      allow(index_entity_service).to receive(:delete)
      subject
      expect(person1.reload.merged_entities).to match_array [person2, person3, person4]
    end

    it "makes the to_keep person the master_entity of all the merged entities" do
      allow(index_entity_service).to receive(:delete)
      subject
      expect(person2.reload.master_entity).to eq person1
      expect(person3.reload.master_entity).to eq person1
      expect(person4.reload.master_entity).to eq person1
    end

    it "clears all of the other entities merged_entities" do
      allow(index_entity_service).to receive(:delete)
      subject
      expect(person2.reload.merged_entities).to be_empty
      expect(person3.reload.merged_entities).to be_empty
      expect(person4.reload.merged_entities).to be_empty
    end

    it "sets merged_entities_count correctly on all entities" do
      allow(index_entity_service).to receive(:delete)
      subject
      expect(person1.reload.merged_entities_count).to eq(3)
      expect(person2.reload.merged_entities_count).to eq(0)
      expect(person3.reload.merged_entities_count).to eq(0)
    end

    it "deletes all the merged people from Elasticsearch" do
      expect(index_entity_service).to receive(:delete).exactly(3).times
      subject
    end
  end

  context "when re-assigning merged people" do
    let!(:person3) { create(:natural_person, master_entity: person2) }

    before do
      allow(index_entity_service).to receive(:delete)
      subject
    end

    subject { NonDestructivePeopleMerger.new(person3, person1).call }

    it "adds the re-assigned people to the new master" do
      expect(person3.reload.master_entity).to eq(person1)
      expect(person1.reload.merged_entities).to include(person3)
    end

    it "removes the re-assigned people from the old master" do
      expect(person2.reload.merged_entities).to be_empty
    end

    it "updates all the merged_entities_count fields" do
      expect(person2.merged_entities_count).to eq(0)
      expect(person1.merged_entities_count).to eq(1)
    end
  end
end
