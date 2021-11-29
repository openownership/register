require 'rails_helper'

RSpec.describe RawDataRecord do
  describe '.bulk_upsert_for_import' do
    let(:import) { create(:import) }

    it 'inserts new records' do
      expect(RawDataRecord.count).to eq(0)
      records = [
        {
          raw_data: "test",
          etag: '2',
        },
      ]
      upserted = RawDataRecord.bulk_upsert_for_import(records, import).upserted_ids
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
      upserted = RawDataRecord.bulk_upsert_for_import(records, second_import).upserted_ids

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
      upserted = RawDataRecord.bulk_upsert_for_import(records, import).upserted_ids
      record = RawDataRecord.find(upserted.first)
      expect(record.etag).to eq(RawDataRecord.etag("test"))
    end

    it "compresses raw_data when it's over the size limit" do
      really_long_string = "a" * (RawDataRecord::RAW_DATA_COMPRESSION_LIMIT + 1)
      records = [
        {
          raw_data: really_long_string,
          etag: '1',
        },
      ]
      upserted = RawDataRecord.bulk_upsert_for_import(records, import).upserted_ids
      record = RawDataRecord.find(upserted.first)
      expect(record.compressed).to be true
      expect(record[:raw_data]).to eq Base64.encode64(Zlib::Deflate.deflate(really_long_string))
    end

    it "skips and raises an error for raw_data which can't be compressed small enough" do
      # I can't think of a performant way to test this without stubbing the
      # constant or otherwise changing the limit
      stub_const "RawDataRecord::MONGODB_MAX_DOC_SIZE", 1
      really_long_string = "a" * (RawDataRecord::RAW_DATA_COMPRESSION_LIMIT + 1)
      records = [
        {
          raw_data: really_long_string,
          etag: '1',
        },
      ]
      expect(Rollbar).to receive(:error)
      expect do
        RawDataRecord.bulk_upsert_for_import(records, import).upserted_ids
      end.not_to change { RawDataRecord.count }
    end
  end

  describe '.etag' do
    it 'generates a reliable etag for the same piece of data' do
      etag = RawDataRecord.etag("test")
      5.times do
        expect(etag).to eq(RawDataRecord.etag("test"))
      end
    end

    it 'generates different etags for different data' do
      expect(RawDataRecord.etag("test1")).not_to eq(RawDataRecord.etag("test"))
    end
  end

  describe '.all_ids_for_entity' do
    let!(:entity) { create(:entity) }
    let!(:raw_records) { create_list(:raw_data_record, 3) }
    let!(:provenances) do
      [
        create(
          :raw_data_provenance,
          raw_data_records: [raw_records[0]],
          entity_or_relationship: entity,
        ),
        create(
          :raw_data_provenance,
          raw_data_records: [raw_records[1], raw_records[2]],
          entity_or_relationship: entity,
        ),
      ]
    end

    it 'returns all the related raw record ids' do
      expected = raw_records.map(&:id)
      expect(RawDataRecord.all_ids_for_entity(entity)).to match_array(expected)
    end

    it 'handles provenances that have no raw records' do
      provenances.first.update_attribute(:raw_data_records, [])
      expected = [raw_records[1].id, raw_records[2].id]
      expect(RawDataRecord.all_ids_for_entity(entity)).to match_array(expected)
    end
  end

  describe '.all_for_entity' do
    let!(:entity) { create(:entity) }
    let!(:raw_records) { create_list(:raw_data_record, 3) }
    let!(:provenances) do
      [
        create(
          :raw_data_provenance,
          raw_data_records: [raw_records[0]],
          entity_or_relationship: entity,
        ),
        create(
          :raw_data_provenance,
          raw_data_records: [raw_records[1], raw_records[2]],
          entity_or_relationship: entity,
        ),
      ]
    end

    it 'returns all the related raw records' do
      expect(RawDataRecord.all_for_entity(entity)).to match_array(raw_records)
    end

    it 'handles provenances that have no raw records' do
      provenances.first.update_attribute(:raw_data_records, [])
      expected = [raw_records[1], raw_records[2]]
      expect(RawDataRecord.all_for_entity(entity)).to match_array(expected)
    end
  end

  describe '.newest_for_entity' do
    let!(:entity) { create(:legal_entity) }
    let!(:raw_data_record1) do
      record = create(:raw_data_record)
      record.timeless.update_attribute(:updated_at, 1.day.ago)
      record
    end
    let!(:raw_data_record2) do
      record = create(:raw_data_record)
      record.timeless.update_attribute(:updated_at, 2.days.ago)
      record
    end
    let!(:provenance) do
      create(
        :raw_data_provenance,
        raw_data_records: [raw_data_record1, raw_data_record2],
        entity_or_relationship: entity,
      )
    end

    it 'returns the newest record by updated_at' do
      expect(RawDataRecord.newest_for_entity(entity)).to eq(raw_data_record1)
    end
  end

  describe '.oldest_for_entity' do
    let!(:entity) { create(:legal_entity) }
    let!(:raw_data_record1) do
      record = create(:raw_data_record)
      record.timeless.update_attribute(:created_at, 1.day.ago)
      record
    end
    let!(:raw_data_record2) do
      record = create(:raw_data_record)
      record.timeless.update_attribute(:created_at, 2.days.ago)
      record
    end
    let!(:provenance) do
      create(
        :raw_data_provenance,
        raw_data_records: [raw_data_record1, raw_data_record2],
        entity_or_relationship: entity,
      )
    end

    it 'returns the oldest record by created_at' do
      expect(RawDataRecord.newest_for_entity(entity)).to eq(raw_data_record2)
    end
  end

  describe '#raw_data' do
    it 'transparently decompresses compressed raw data' do
      data = { test: "test" }.to_json
      compressed_data = Base64.encode64 Zlib::Deflate.deflate(data)
      raw_record = create(:raw_data_record, raw_data: compressed_data, compressed: true)
      expect(raw_record.raw_data).to eq data
    end

    it 'returns uncompressed raw data as-is' do
      data = { test: "test" }.to_json
      raw_record = create(:raw_data_record, raw_data: data)
      expect(raw_record.raw_data).to eq data
    end
  end

  describe '#data_sources' do
    let(:imports) { create_list(:import, 3) }
    let(:record) { create(:raw_data_record, imports: imports) }
    let(:data_sources) { imports.map(&:data_source) }

    it 'returns all the data sources attached to this record via imports' do
      expect(record.data_sources).to match_array(data_sources)
    end
  end

  describe '#latest_import' do
    let(:imports) do
      (0..2).map do |i|
        import = create(:import)
        import.timeless.update_attribute(:created_at, i.days.ago)
        import
      end
    end
    let(:record) { create(:raw_data_record, imports: imports) }

    it 'returns the most recently created import' do
      expect(record.most_recent_import).to eq(imports[0])
    end
  end

  describe '#seen_in_most_recent_import?' do
    let(:imports) do
      (0..2).map do |i|
        import = create(:import)
        import.timeless.update_attribute(:created_at, i.days.ago)
        import
      end
    end
    let(:record) { create(:raw_data_record, imports: imports) }

    context "when the record's most recent import is the same as its data source's" do
      it 'returns true' do
        expect(record.seen_in_most_recent_import?).to be true
      end
    end

    context "when any data source has had a newer import" do
      let!(:new_import) { create(:import, data_source: imports[0].data_source) }

      it 'returns false' do
        expect(record.seen_in_most_recent_import?).to be true
      end
    end
  end
end
