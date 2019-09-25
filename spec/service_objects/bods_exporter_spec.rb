require 'rails_helper'

RSpec.describe BodsExporter do
  before do
    # Don't leave tmp files all over the place
    allow(FileUtils).to receive(:mkdir_p)
  end

  after(:each) do
    redis = Redis.new
    redis.flushdb
    redis.close
  end

  describe '#new' do
    it 'defaults to a chunk size of 100' do
      exporter = BodsExporter.new
      expect(exporter.chunk_size).to eq 100
    end

    it 'allows you to override the chunk_size' do
      exporter = BodsExporter.new(chunk_size: 1)
      expect(exporter.chunk_size).to eq 1
    end

    it 'creates a new export' do
      expect { BodsExporter.new }.to change { BodsExport.count }.by(1)
    end
  end

  describe '#call' do
    let!(:legal_entity_1) { create(:legal_entity) }
    let!(:legal_entity_2) { create(:legal_entity) }

    subject { BodsExporter.new(chunk_size: 1) }

    it 'enqueues a BodsExportWorker for every chunk of entities' do
      expect { subject.call }.to change(BodsExportWorker.jobs, :size).by(2)
      export = subject.export
      expected_args = [
        [[legal_entity_1.id.to_s], export.id.to_s],
        [[legal_entity_2.id.to_s], export.id.to_s],
      ]
      expect(BodsExportWorker.jobs.first['args']).to eq expected_args[0]
      expect(BodsExportWorker.jobs.second['args']).to eq expected_args[1]
    end

    context "when there have been other completed exports" do
      before do
        legal_entity_1.set(updated_at: '2019-01-01 00:00:00')
        legal_entity_2.set(updated_at: '2019-01-02 00:00:00')
        # Note that the export started after legal_entity_1 but finished after
        # legal_entity_2 was updated. It would have processed legal_entity_1
        # but since it builds the list of ids to process at the beginning it
        # wouldn't have seen legal_entity_2.
        create(
          :bods_export,
          created_at: '2019-01-01 01:00:00',
          completed_at: '2019-01-03 00:00:00',
        )
      end

      it "only enqueues jobs for entities which have changed since" do
        expect { subject.call }.to change(BodsExportWorker.jobs, :size).by(1)
        export = subject.export
        expected_args = [[legal_entity_2.id.to_s], export.id.to_s]
        expect(BodsExportWorker.jobs.first['args']).to eq expected_args
      end
    end

    context "when an existing ids list is provided" do
      let(:existing_ids) { %w[abc123 def456] }

      it 'loads the statement ids into redis' do
        BodsExporter.new(existing_ids: existing_ids).call
        redis = Redis.new
        loaded = redis.smembers(BodsExport::REDIS_ALL_STATEMENTS_SET)
        redis.close
        expect(loaded).to match_array(existing_ids)
      end
    end
  end
end
