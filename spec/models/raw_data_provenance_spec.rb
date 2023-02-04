require 'rails_helper'

RSpec.describe RawDataProvenance do
  describe '.all_for_entity' do
    let!(:entity) { create(:natural_person) }
    let!(:provenances) do
      create_list(:raw_data_provenance, 3, entity_or_relationship: entity)
    end

    it 'returns all the provenances attached to an entity' do
      expect(RawDataProvenance.all_for_entity(entity)).to match_array(provenances)
    end

    context 'when the entity has merged entities' do
      let!(:merged_entities) do
        create_list(:natural_person, 3, master_entity: entity)
      end

      let!(:merged_provenances) do
        merged_entities.map do
          create_list(:raw_data_provenance, 3, entity_or_relationship: entity)
        end.flatten
      end

      it "returns merged entities' provenances too" do
        expected = provenances + merged_provenances
        expect(RawDataProvenance.all_for_entity(entity)).to match_array(expected)
      end
    end
  end
end
