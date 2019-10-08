require 'rails_helper'

RSpec.describe NonDestructivePeopleMerger do
  let(:person_1) { create(:natural_person) }
  let(:person_2) { create(:natural_person) }
  let(:index_entity_service) { instance_double(IndexEntityService) }

  before do
    allow(IndexEntityService).to receive(:new).and_return(index_entity_service)
  end

  context "when one of the entities is not a person" do
    let(:company) { create(:legal_entity) }

    it "raises an error" do
      expect do
        NonDestructivePeopleMerger.new(company, person_1).call
      end.to raise_error('to_merge is not a person')

      expect do
        NonDestructivePeopleMerger.new(person_1, company).call
      end.to raise_error('to_keep is not a person')
    end

    it "doesn't merge them" do
      expect do
        NonDestructivePeopleMerger.new(company, person_1).call
      rescue StandardError # rubocop:disable Lint/HandleExceptions
      end.not_to change { person_1.merged_entities.count }

      expect do
        NonDestructivePeopleMerger.new(person_1, company).call
      rescue StandardError # rubocop:disable Lint/HandleExceptions
      end.not_to change { company.merged_entities.count }
    end
  end

  context "when the people are the same" do
    it "raises an error" do
      expect do
        NonDestructivePeopleMerger.new(person_1, person_1).call
      end.to raise_error('Trying to merge the same entity')
    end

    it "doesn't merge them" do
      expect do
        NonDestructivePeopleMerger.new(person_1, person_1).call
      rescue StandardError # rubocop:disable Lint/HandleExceptions
      end.not_to change { person_1.merged_entities.count }
    end
  end

  context "when the people are mergeable" do
    subject { NonDestructivePeopleMerger.new(person_2, person_1).call }

    it "adds the to_merge person to the to_keep person's merged_entities" do
      allow(index_entity_service).to receive(:delete)
      subject
      expect(person_1.reload.merged_entities).to match_array [person_2]
    end

    it "makes the to_keep person the to_merge person's master_entity" do
      allow(index_entity_service).to receive(:delete)
      subject
      expect(person_2.reload.master_entity).to eq person_1
    end

    it "sets merged_entities_count on the to_keep entity" do
      allow(index_entity_service).to receive(:delete)
      subject
      expect(person_1.reload.merged_entities_count).to eq(1)
    end

    it "deletes the to_merge person from Elasticsearch" do
      expect(index_entity_service).to receive(:delete)
      subject
    end
  end

  context "when the people to merge already have merged people" do
    let!(:person_3) { create(:natural_person, master_entity: person_2) }
    let!(:person_4) { create(:natural_person, master_entity: person_3) }

    subject { NonDestructivePeopleMerger.new(person_2, person_1).call }

    it "adds all of the entities to the to_keep person's merged_entities" do
      allow(index_entity_service).to receive(:delete)
      subject
      expect(person_1.reload.merged_entities).to match_array [person_2, person_3, person_4]
    end

    it "makes the to_keep person the master_entity of all the merged entities" do
      allow(index_entity_service).to receive(:delete)
      subject
      expect(person_2.reload.master_entity).to eq person_1
      expect(person_3.reload.master_entity).to eq person_1
      expect(person_4.reload.master_entity).to eq person_1
    end

    it "clears all of the other entities merged_entities" do
      allow(index_entity_service).to receive(:delete)
      subject
      expect(person_2.reload.merged_entities).to be_empty
      expect(person_3.reload.merged_entities).to be_empty
      expect(person_4.reload.merged_entities).to be_empty
    end

    it "sets merged_entities_count correctly on all entities" do
      allow(index_entity_service).to receive(:delete)
      subject
      expect(person_1.reload.merged_entities_count).to eq(3)
      expect(person_2.reload.merged_entities_count).to eq(0)
      expect(person_3.reload.merged_entities_count).to eq(0)
    end

    it "deletes all the merged people from Elasticsearch" do
      expect(index_entity_service).to receive(:delete).exactly(3).times
      subject
    end
  end

  context "when re-assigning merged people" do
    let!(:person_3) { create(:natural_person, master_entity: person_2) }

    before do
      allow(index_entity_service).to receive(:delete)
      subject
    end

    subject { NonDestructivePeopleMerger.new(person_3, person_1).call }

    it "adds the re-assigned people to the new master" do
      expect(person_3.reload.master_entity).to eq(person_1)
      expect(person_1.reload.merged_entities).to include(person_3)
    end

    it "removes the re-assigned people from the old master" do
      expect(person_2.reload.merged_entities).to be_empty
    end

    it "updates all the merged_entities_count fields" do
      expect(person_2.merged_entities_count).to eq(0)
      expect(person_1.merged_entities_count).to eq(1)
    end
  end
end
