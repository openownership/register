require 'rails_helper'

RSpec.describe RawDataRecord do
  describe '.bulk_save_for_import' do
    let(:import) { create(:import) }

    it 'inserts new records' do
      expect(RawDataRecord.count).to eq(0)
      records = [
        {
          raw_data: "test",
          etag: '2',
        },
      ]
      upserted = RawDataRecord.bulk_save_for_import(records, import)
      expect(upserted.length).to eq(1)
      record = RawDataRecord.find(upserted.first)
      expect(record.raw_data).to eq('test')
      expect(record.etag).to eq('2')
      expect(record.created_at).to be_within(1.second).of(Time.zone.now)
      expect(record.updated_at).to be_within(1.second).of(Time.zone.now)
      expect(record.import_ids).to match_array([import.id])
    end

    it 'upserts the import id and updated_at on existing records' do
      existing_record = create(:raw_data_record, imports: [import])
      second_import = create(:import, data_source: import.data_source)
      records = [
        {
          raw_data: existing_record.raw_data,
          etag: existing_record.etag,
        },
      ]
      upserted = RawDataRecord.bulk_save_for_import(records, second_import)

      expect(upserted.length).to eq(0)
      upserted_record = RawDataRecord.find(existing_record.id)
      expect(upserted_record.raw_data).to eq(existing_record.raw_data)
      expect(upserted_record.etag).to eq(existing_record.etag)
      # Bit of a rubbish test, but millisecond precision issues mean it won't
      # always be 'equal' even when it is
      expect(upserted_record.created_at).to be_within(1.second).of(existing_record.created_at)
      expect(upserted_record.updated_at).to be > existing_record.updated_at
      expect(upserted_record.import_ids).to match_array([import.id, second_import.id])
    end

    it 'generates an etag from the data for records without it' do
      records = [
        {
          raw_data: "test",
          etag: nil,
        },
      ]
      upserted = RawDataRecord.bulk_save_for_import(records, import)
      record = RawDataRecord.find(upserted.first)
      expect(record.etag).to eq(RawDataRecord.etag("test"))
    end
  end
end
