require 'rails_helper'

RSpec.describe UploadFile do
  let(:file) { Tempfile.new }
  let(:name) { 'upload' }

  context 'when using doubles' do
    let(:s3) { instance_double Aws::S3::Resource, bucket: bucket }
    let(:bucket) { instance_double Aws::S3::Bucket, object: object }
    let(:object) { instance_double Aws::S3::Object, upload_file: nil }
    let(:pull_request_number) { instance_double PullRequestNumber, call: 'pr-123' }

    it 'uploads a file' do
      described_class.from(file, to: name, s3: s3, pr: pull_request_number)

      expect(s3).to have_received(:bucket).with ENV['BUCKETEER_BUCKET_NAME']
      expect(bucket).to have_received(:object).with 'public/pr-123/upload'
      expect(object).to have_received(:upload_file).with file.path
    end

    context 'when no pull request number' do
      before { allow(pull_request_number).to receive(:call).and_return nil }

      it 'selects correct path' do
        described_class.from(file, to: name, s3: s3, pr: pull_request_number)

        expect(bucket).to have_received(:object).with 'public/upload'
      end
    end
  end

  context 'when using real AWS Resource but stubbed' do
    let(:s3) { Aws::S3::Resource.new(stub_responses: true) }

    it 'uploads a file' do
      expect(described_class.from(file, to: name, s3: s3)).to be true
    end
  end
end
