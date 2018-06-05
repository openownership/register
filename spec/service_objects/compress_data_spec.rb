# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CompressData do
  let(:data) { 'data' }
  let(:name) { 'entities' }
  let(:export) { instance_double ModelExport, name: name }
  let(:gz_writer) { instance_double Zlib::GzipWriter, puts: nil }

  before do
    allow(export).to receive(:each).and_yield data
  end

  it 'opens tempfile in binary mode' do
    allow(Tempfile).to receive(:open)

    described_class.call(export)
    expect(Tempfile).to have_received(:open).with([name, '.jsonl.gz'], binmode: true)
  end

  it 'names tempfile correctly' do
    allow(Zlib::GzipWriter).to receive(:open)

    tempfile = described_class.call(export)

    expect(tempfile.path).to match %r{^#{Dir.tmpdir}/entities.*\.jsonl.gz$}
  end

  it 'compresses the data' do
    tempfile = described_class.call(export)
    result = Zlib::GzipReader.open(tempfile.path, &:read)

    expect(result).to eq data
  end
end
