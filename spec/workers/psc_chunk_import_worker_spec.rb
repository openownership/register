require 'rails_helper'
require 'support/fixture_helpers'

RSpec.describe PscChunkImportWorker do
  let(:data_source) { create(:psc_data_source) }
  let(:import) { create(:import) }
  let(:line) { file_fixture('psc_corporate.json').read }
  let(:records) { [JSON.parse(line)] }
  let(:chunk) { ChunkHelper.to_chunk([line]) }
  let(:retrieved_at) { Time.zone.local(2011, 2, 3, 4, 5, 6) }

  subject do
    PscChunkImportWorker.new.perform(chunk, retrieved_at.to_s, import.id.to_s)
  end

  it 'creates and calls a PscImporter to process the records' do
    stub_importer = double PscImporter
    expect(PscImporter).to receive(:new).and_return stub_importer
    expect(stub_importer).to receive(:retrieved_at=).with(retrieved_at)
    expect(stub_importer).to receive(:import=).with(import)
    expect(stub_importer).to receive(:process_records).with(records)
    subject
  end
end
