require 'rails_helper'

RSpec.describe SkImportTrigger do
  let(:data_source) { create(:sk_data_source) }
  let(:sk_client) { instance_double('SkClient') }
  let(:dummy_data) do
    [
      { "test": "test1" },
      { "test": "test2" },
      { "test": "test3" },
    ]
  end

  before do
    allow(SkClient).to receive(:new).and_return(sk_client)
  end

  describe "#call" do
    before do
      allow(sk_client).to receive(:all_records).and_return(dummy_data)
    end

    subject { SkImportTrigger.new.call(data_source, 1) }

    it 'creates an Import for the given data_source' do
      expect do
        subject
      end.to change { Import.where(data_source: data_source).count }.by(1)
    end

    it 'creates RawDataRecords for all of the results' do
      expect { subject }.to change { RawDataRecord.count }.by(3)
    end

    it 'queues up RawDataRecordsImportWorkers for each chunk of results' do
      expect { subject }.to change(RawDataRecordsImportWorker.jobs, :size).by(3)
    end

    it 'only queues up RawDataRecordsImportWorkers for new or changed records' do
      subject
      updated_dummy_data = dummy_data
      updated_dummy_data << { "test": "test4" }
      allow(sk_client).to receive(:all_records).and_return(updated_dummy_data)
      RawDataRecordsImportWorker.jobs.clear
      expect do
        SkImportTrigger.new.call(data_source, 1)
      end.to change(RawDataRecordsImportWorker.jobs, :size).by(1)
      record_id = RawDataRecordsImportWorker.jobs.first['args'].first.first
      raw_record = RawDataRecord.find(record_id)
      expect(raw_record.raw_data).to eq({ "test": "test4" }.to_json)
    end
  end
end
