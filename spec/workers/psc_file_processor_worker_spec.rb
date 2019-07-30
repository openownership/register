require 'rails_helper'

RSpec.describe PscFileProcessorWorker do
  let(:import) { create(:import) }
  let(:corporate_record) { file_fixture('psc_corporate.json').read }
  let(:corporate_etag) { RawDataRecord.etag(JSON.parse(corporate_record)) }
  let(:individual_record) { file_fixture('psc_individual.json').read }
  let(:individual_etag) { RawDataRecord.etag(JSON.parse(individual_record)) }
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
      first_record = RawDataRecord.find_by(etag: corporate_etag)
      expect(first_record.data).to eq(JSON.parse(corporate_record))
      expect(first_record.imports).to eq([import])
      expect(first_record.created_at).to be_within(1.second).of(Time.zone.now)
      expect(first_record.updated_at).to be_within(1.second).of(Time.zone.now)

      second_record = RawDataRecord.find_by(etag: individual_etag)
      expect(second_record.data).to eq(JSON.parse(individual_record))
      expect(second_record.imports).to eq([import])
      expect(second_record.created_at).to be_within(1.second).of(Time.zone.now)
      expect(second_record.updated_at).to be_within(1.second).of(Time.zone.now)
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

    context "when there's an existing record with the same etag" do
      let!(:existing_record) do
        RawDataRecord.create!(
          imports: create_list(:import, 2),
          data: JSON.parse(corporate_record),
          etag: corporate_etag,
        )
      end

      it "updates the existing record" do
        subject
        expect(existing_record.reload.imports.count).to eq(3)
        expect(existing_record.updated_at).to be_within(1.second).of(Time.zone.now)
      end

      it "still queues up a PscChunkImportWorker for the record" do
        expect { subject }.to change(PscChunkImportWorker.jobs, :size).by(2)
      end
    end
  end

  it 'queues up PscChunkImportWorkers for each chunk' do
    expect { subject }.to change(PscChunkImportWorker.jobs, :size).by(2)
  end
end
