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
        begin
          NonDestructivePeopleMerger.new(company, person_1).call
        rescue StandardError # rubocop:disable Lint/HandleExceptions
        end
      end.not_to change { person_1.merged_entities.count }

      expect do
        begin
          NonDestructivePeopleMerger.new(person_1, company).call
        rescue StandardError # rubocop:disable Lint/HandleExceptions
        end
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
        begin
          NonDestructivePeopleMerger.new(person_1, person_1).call
        rescue StandardError # rubocop:disable Lint/HandleExceptions
        end
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

    it "deletes the to_merge person from Elasticsearch" do
      expect(index_entity_service).to receive(:delete)
      subject
    end
  end
end
