require 'rails_helper'

RSpec.describe NaturalPersonsDuplicatesMerger do
  before do
    allow(Rails.logger).to receive(:info)
  end

  context 'with no entities' do
    let :expected_stats do
      {
        processed: 0,
        candidates: 0,
        merges: 0,
      }
    end

    it 'does not process any entities' do
      expect(subject.run).to eq expected_stats
    end

    it 'logs stats at the end' do
      expect(Rails.logger).to receive(:info)
        .with("[NaturalPersonsDuplicatesMerger] Run finished with stats: #{expected_stats.to_json}")

      subject.run
    end
  end

  context 'with entities' do
    context 'with no duplicates' do
      let!(:entities) { create_list :natural_person, 3 }

      before do
        # Create some legal entities to make sure we skip these
        create_list :legal_entity, 2

        expect(IndexEntityService).to receive(:new).never
      end

      let :expected_stats do
        {
          processed: entities.size,
          candidates: 0,
          merges: 0,
        }
      end

      it 'processes the entities but does not find any merge candidates' do
        expect(subject.run).to eq expected_stats
        expect(Entity.natural_persons.where(master_entity: nil)).to match_array entities
      end
    end

    context 'with some groups of duplicates' do
      let(:index_entity_service) { instance_double('IndexEntityService') }
      let(:dup_name_1) { 'name 1' }
      let(:dup_name_2) { 'name 2' }
      let(:dup_address_1) { 'address 1' }
      let(:dup_address_2) { 'address 2' }
      let(:dup_dob_1) { 10.years.ago.to_date.to_s }
      let(:dup_dob_2) { 10.years.ago.to_date.to_s }

      let! :dup_entities_1 do
        create_list(
          :natural_person,
          3,
          name: dup_name_1,
          address: dup_address_1,
          dob: dup_dob_1,
        )
      end

      let! :dup_entities_2 do
        create_list(
          :natural_person,
          2,
          name: dup_name_2,
          address: dup_address_2,
          dob: dup_dob_2,
        )
      end

      let! :similar_but_not_quite_dup_entities do
        e1 = create :natural_person, name: dup_name_1, dob: dup_dob_1, address: 'foo'
        e2 = create :natural_person, name: dup_name_1, dob: dup_dob_1, address: nil
        e3 = create :natural_person, name: dup_name_1
        e4 = create :natural_person, name: dup_name_1, dob: nil, address: nil
        e5 = create :natural_person, name: dup_name_2, address: dup_address_1, dob: dup_dob_2
        [e1, e2, e3, e4, e5]
      end

      let! :non_dup_entities do
        create_list :natural_person, 4
      end

      before do
        # Create some legal entities to make sure we skip these
        create_list :legal_entity, 2

        allow(IndexEntityService).to receive(:new).and_return index_entity_service
      end

      let :expected_stats do
        size = dup_entities_1.size + dup_entities_2.size + similar_but_not_quite_dup_entities.size + non_dup_entities.size

        {
          processed: size,
          candidates: 1 + 1,
          merges: (dup_entities_1.size + dup_entities_2.size) - 2,
        }
      end

      let(:expected_dup_1_merged) { [dup_entities_1[1], dup_entities_1[2]] }
      let(:expected_dup_2_merged) { [dup_entities_2[1]] }

      it 'processes the entities, finds merge candidates and merges them' do
        expect(index_entity_service).to receive(:delete).exactly(expected_stats[:merges]).times
        expect(subject.run).to eq expected_stats
        expect(dup_entities_1[0].merged_entities).to match_array(expected_dup_1_merged)
        expect(dup_entities_2[0].merged_entities).to match_array(expected_dup_2_merged)
      end
    end
  end
end
