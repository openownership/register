require 'rails_helper'

RSpec.describe S3FakeAdapter do
  subject { described_class.new }

  let(:s3_bucket) { 's3_bucket' }
  let(:existing_s3_path) { 'existing/path/to/data' }
  let(:existing_content) { 'existing_content' }
  let(:new_local_path) { File.join(@temp_dir, 'local_path') }

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @temp_dir = dir
      example.run
    end
  end

  before do
    subject.upload_to_s3_without_file(
      s3_bucket: s3_bucket,
      s3_path: existing_s3_path,
      content: existing_content,
      compress: false
    )
  end

  describe '#download_from_s3' do
    context 'when s3_path matches an existing file in bucket' do
      it 'downloads file to path' do
        subject.download_from_s3(s3_bucket: s3_bucket, s3_path: existing_s3_path, local_path: new_local_path)
        expect(File.read(new_local_path)).to eq existing_content
      end
    end

    context 'when s3_path does not match an existing file in bucket' do
      let(:non_existing_path) { 'non-existing/path/to/data' }

      it 'raises a S3FakeAdapter::Errors::NoSuchKey error' do
        expect do
          subject.download_from_s3(s3_bucket: s3_bucket, s3_path: non_existing_path, local_path: new_local_path)
        end.to raise_error(S3FakeAdapter::Errors::NoSuchKey)
      end
    end

    context 'when s3_path only matches file in different bucket' do
      let(:incorrect_bucket) { 'incorrect_bucket' }

      it 'raises a S3FakeAdapter::Errors::NoSuchKey error' do
        expect do
          subject.download_from_s3(s3_bucket: incorrect_bucket, s3_path: existing_s3_path, local_path: new_local_path)
        end.to raise_error(S3FakeAdapter::Errors::NoSuchKey)
      end
    end
  end

  describe '#upload_to_s3' do
    context 'when uploading existing local file' do
      let(:local_path) { File.join(@temp_dir, 'local_path')  }

      before do
        File.open(local_path, 'w') { |f| f.write existing_content }
      end

      it 'exists in s3 bucket afterwards' do
        s3_path = 'some/path'
        subject.upload_to_s3(s3_bucket: s3_bucket, s3_path: s3_path, local_path: local_path)

        subject.download_from_s3(s3_bucket: s3_bucket, s3_path: s3_path, local_path: new_local_path)
        expect(File.read(new_local_path)).to eq existing_content
      end
    end
  end

  describe '#copy_file_in_s3' do
    context 'when uploading existing local file' do
      let(:local_path) { File.join(@temp_dir, 'local_path')  }

      before do
        File.open(local_path, 'w') { |f| f.write existing_content }
      end

      it 'can be copied to a new s3 path' do
        new_s3_path = 'new/path'
        subject.copy_file_in_s3(s3_bucket: s3_bucket, s3_path_from: existing_s3_path, s3_path_to: new_s3_path)

        subject.download_from_s3(s3_bucket: s3_bucket, s3_path: new_s3_path, local_path: new_local_path)
        expect(File.read(new_local_path)).to eq existing_content
      end
    end
  end

  describe '#upload_to_s3_without_file' do
    let(:new_s3_path) { 'new/path' }
    let(:new_content) { 'new content' }

    context 'when compress is true' do
      it 'uploads file compressed with gzip' do
        subject.upload_to_s3_without_file(
          s3_bucket: s3_bucket,
          s3_path: new_s3_path,
          content: new_content,
          compress: true
        )

        subject.download_from_s3(s3_bucket: s3_bucket, s3_path: new_s3_path, local_path: new_local_path)

        file_content = Zlib::GzipReader.open(new_local_path, &:read)
        expect(file_content).to eq new_content
      end
    end

    context 'when compress is false' do
      it 'uploads raw file' do
        subject.upload_to_s3_without_file(
          s3_bucket: s3_bucket,
          s3_path: new_s3_path,
          content: new_content,
          compress: false
        )

        subject.download_from_s3(s3_bucket: s3_bucket, s3_path: new_s3_path, local_path: new_local_path)
        expect(File.read(new_local_path)).to eq new_content
      end
    end
  end
end
