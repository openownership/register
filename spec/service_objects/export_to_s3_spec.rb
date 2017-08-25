require 'rails_helper'

RSpec.describe ExportToS3 do
  subject { described_class.new(export) }

  let(:archive) { instance_double Tempfile, unlink: nil }
  let(:data) { 'exported data' }
  let(:filename) { 'entities.jsonl.gz' }
  let(:export) { instance_double ModelExport, name: 'entities' }

  before do
    allow_any_instance_of(CompressData).to receive(:call).and_return archive
    allow(UploadFile).to receive(:from)
  end

  describe '#call' do
    it 'compresses and uploads file to s3' do
      subject.call

      expect(UploadFile).to have_received(:from).with(archive, to: filename)
    end

    it 'removes file once uploaded' do
      subject.call

      expect(archive).to have_received(:unlink)
    end
  end
end
