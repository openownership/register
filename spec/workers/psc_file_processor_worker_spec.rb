require 'rails_helper'
require 'xxhash'

RSpec.describe PscFileProcessorWorker do
  let(:import) { create(:import) }
  let(:corporate_record) { file_fixture('psc_corporate.json').read }
  let(:corporate_etag) { XXhash.xxh64(corporate_record).to_s }
  let(:individual_record) { file_fixture('psc_individual.json').read }
  let(:individual_etag) { XXhash.xxh64(individual_record).to_s }
  let(:file) do
    file = corporate_record
    file += individual_record
    file
  end
  let(:source_url) { 'http://example.com/data.json' }

  before do
    stub_request(:get, source_url).to_return(body: file)
  end

  subject { PscFileProcessorWorker.new.perform(source_url, 1, import.id.to_s) }

  describe 'Saving RawDataRecords' do
    it 'saves each line in the file as a RawDataRecord' do
      expect { subject }.to change { RawDataRecord.count }.by(2)
    end

    context 'when etags are present in the data' do
      let(:corporate_etag) { 'etag_1' }
      let(:corporate_record) do
        record = JSON.parse(file_fixture('psc_corporate.json').read)
        record['data']['etag'] = corporate_etag
        record.to_json + "\n"
      end
      let(:individual_etag) { 'etag_2' }
      let(:individual_record) do
        record = JSON.parse(file_fixture('psc_corporate.json').read)
        record['data']['etag'] = individual_etag
        record.to_json + "\n"
      end

      it 'uses those etags for the RawDataRecords' do
        subject
        expect(RawDataRecord.where(etag: corporate_etag)).to exist
        expect(RawDataRecord.where(etag: individual_etag)).to exist
      end
    end

    it 'creates an etag from the data if none is present' do
      subject
      expect(RawDataRecord.first.etag).to eq corporate_etag
      expect(RawDataRecord.last.etag).to eq individual_etag
    end

    it "updates existing RawDataRecords if the etag hasn't changed" do
      record = RawDataRecord.create!(
        imports: create_list(:import, 2),
        data: JSON.parse(corporate_record),
        etag: corporate_etag,
      )
      subject
      expect(record.reload.imports.count).to eq(3)
    end

    context "when there's a race condition finding existing RawDataRecords" do
      let!(:existing_record) do
        RawDataRecord.create!(
          imports: create_list(:import, 2),
          data: JSON.parse(corporate_record),
          etag: corporate_etag,
        )
      end

      before do
        allow(RawDataRecord)
          .to(receive(:find_or_initialize_by))
          .with(etag: individual_etag)
          .and_call_original

        # Simulate a race condition by denying the existence of the existing
        # record on the first call to find_or_initialize_by
        allow(RawDataRecord)
          .to(receive(:find_or_initialize_by))
          .with(etag: corporate_etag)
          .and_return(RawDataRecord.new(etag: corporate_etag), existing_record)
      end

      it 'retries saving and adds the import to the existing record' do
        expect { subject }.to change { RawDataRecord.count }.from(1).to(2)
        expect(existing_record.reload.imports.count).to eq(3)
      end
    end
  end

  it 'queues up PscChunkImportWorkers for each chunk' do
    expect { subject }.to change(PscChunkImportWorker.jobs, :size).by(2)
  end
end
