require 'rails_helper'

RSpec.describe RawDataProvenance do
  describe '.bulk_upsert_for_import' do
    let(:import) { create(:import) }
    let(:raw_data_record) { create(:raw_data_record, imports: [import]) }
    let(:relationship) { create(:relationship) }
    let(:provenance_data) do
      {
        raw_data_record.id.to_s => [
          relationship,
          relationship.source,
          relationship.target,
        ],
      }
    end

    it 'inserts new records for all the entities or relationships' do
      result = RawDataProvenance.bulk_upsert_for_import(import, provenance_data)

      expect(result.upserted_ids.length).to eq(3)

      [relationship, relationship.source, relationship.target].each do |e_or_r|
        provenance = RawDataProvenance.find_by(entity_or_relationship: e_or_r)
        expect(provenance.import).to eq(import)
        expect(provenance.created_at).to be_within(1.second).of(Time.zone.now)
        expect(provenance.updated_at).to be_within(1.second).of(Time.zone.now)
        expect(provenance.raw_data_records).to match_array([raw_data_record])
      end
    end

    context 'when given a new raw record for the same record in the same import' do
      let(:new_raw_record) { create(:raw_data_record, imports: [import]) }
      let(:new_provenance_data) do
        {
          new_raw_record.id.to_s => [
            relationship,
            relationship.source,
            relationship.target,
          ],
        }
      end

      it 'upserts the raw_data_record id and updated_at' do
        RawDataProvenance.bulk_upsert_for_import(import, provenance_data)
        RawDataProvenance.bulk_upsert_for_import(import, new_provenance_data)

        [relationship, relationship.source, relationship.target].each do |e_or_r|
          provenance = RawDataProvenance.find_by(entity_or_relationship: e_or_r)
          expect(provenance.import).to eq(import)
          expect(provenance.created_at).to be_within(1.second).of(Time.zone.now)
          expect(provenance.updated_at).to be > provenance.created_at
          expected_raw_records = [raw_data_record, new_raw_record]
          expect(provenance.raw_data_records).to match_array(expected_raw_records)
        end
      end
    end

    it 'skips empty or missing lists of provenances' do
      empty_provenance_data = {
        raw_data_record.id.to_s => [],
        raw_data_record.id.to_s => nil,
      }
      expect do
        RawDataProvenance.bulk_upsert_for_import(import, empty_provenance_data)
      end.not_to change { RawDataProvenance.count }
    end

    it 'returns the result of the bulk_write call' do
      result = RawDataProvenance.bulk_upsert_for_import(import, provenance_data)
      expect(result).to be_a(Mongo::BulkWrite::Result)
    end
  end

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
