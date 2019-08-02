require 'rails_helper'

RSpec.describe DkImportTrigger do
  let(:data_source) { create(:dk_data_source) }
  let(:dk_client) { instance_double("DkClient") }
  let(:dummy_data) do
    [
      {
        'enhedsNummer' => 1,
        'sidstOpdateret' => '2019-01-01T00:00:0.000+01:00',
      },
      {
        'enhedsNummer' => 2,
        'sidstOpdateret' => '2018-01-01T00:00:00.000+01:00',
      },
      {
        'enhedsNummer' => 3,
        'sidstOpdateret' => '2017-01-01T00:00:00.000+01:00',
      },
    ]
  end

  before do
    allow(DkClient).to receive(:new).and_return(dk_client)
  end

  describe "#call" do
    before do
      allow(dk_client).to receive(:all_records).and_return(dummy_data)
    end

    subject { DkImportTrigger.new.call(data_source, 1) }

    it 'creates an Import for the given data_source' do
      expect do
        subject
      end.to change { Import.where(data_source: data_source).count }.by(1)
    end

    it 'creates RawDataRecords for all of the results' do
      expect { subject }.to change { RawDataRecord.count }.from(0).to(3)
    end

    it 'queues up DkChunkImportWorkers for each chunk of results' do
      expect { subject }.to change(DkChunkImportWorker.jobs, :size).by(3)
    end

    it 'only queues up DkChunkImportWorkers for new or changed records' do
      # Given
      # We've loaded the initial set of data
      subject
      # When
      # We get some updated data, with a new updated date on an existing record
      # and an wholly new record
      updated_dummy_data = dummy_data
      updated_dummy_data.second['sidstOpdateret'] = '2019-01-01T00:00:0.000+01:00'
      updated_dummy_data << {
        'enhedsNummer' => 4,
        'sidstOpdateret' => '2019-01-01T00:00:0.000+01:00',
      }
      allow(dk_client).to receive(:all_records).and_return(updated_dummy_data)
      # And we process that new data
      # Then we enqueue two new jobs to import those changed records
      DkChunkImportWorker.jobs.clear
      expect do
        DkImportTrigger.new.call(data_source, 1)
      end.to change(DkChunkImportWorker.jobs, :size).by(2)
      record_ids = DkChunkImportWorker.jobs.map { |job| job['args'].first }
      raw_records = RawDataRecord.find(record_ids)
      expect(raw_records.first.raw_data).to eq(updated_dummy_data.second.to_json)
      expect(raw_records.last.raw_data).to eq(updated_dummy_data.last.to_json)
    end

    context 'when a result has an enhedsNummer and sidtsOpdateret' do
      it 'uses that as the etag' do
        subject
        record_ids = DkChunkImportWorker.jobs.map { |job| job['args'].first }
        etags = RawDataRecord.find(record_ids).pluck(:etag)
        expected_etags = dummy_data.map do |datum|
          RawDataRecord.etag "#{datum['sidstOpdateret']}_#{datum['enhedsNummer']}"
        end
        expect(etags).to match_array(expected_etags)
      end
    end

    context 'when a result is missing an enhedsNummer or sidtsOpdateret' do
      let(:dummy_data) do
        [
          {
            'enhedsNummer' => 1,
          },
          {
            'sidstOpdateret' => '2018-01-01T00:00:00.000+01:00',
          },
          {
            'test' => 'test',
          },
        ]
      end

      it 'leaves the etag blank, so that one is calculated from the data' do
        subject
        record_ids = DkChunkImportWorker.jobs.map { |job| job['args'].first }
        etags = RawDataRecord.find(record_ids).pluck(:etag)
        expected_etags = dummy_data.map do |datum|
          RawDataRecord.etag datum.to_json
        end
        expect(etags).to match_array(expected_etags)
      end
    end
  end
end
