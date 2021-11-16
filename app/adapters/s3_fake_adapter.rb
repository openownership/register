class S3FakeAdapter
  module Errors
    NoSuchKey = Class.new(StandardError)
  end

  def initialize(**kwargs)
    @files = {}
  end

  def download_from_s3(s3_bucket:, s3_path:, local_path:)
    file_key = generate_file_key(s3_bucket, s3_path)
    raise Errors::NoSuchKey unless files.key?(file_key)
    File.open(local_path, 'wb') { |f| f.write(files[file_key]) }
  end

  def upload_to_s3(s3_bucket:, s3_path:, local_path:)
    content = File.read(local_path)
    file_key = generate_file_key(s3_bucket, s3_path)
    files[file_key] = content
  end

  def copy_file_in_s3(s3_bucket:, s3_path_from:, s3_path_to:)
    file_key_from = generate_file_key(s3_bucket, s3_path_from)
    file_key_to = generate_file_key(s3_bucket, s3_path_to)
    files[file_key_to] = files[file_key_from]
  end

  # Method used in tests to populate initial sample data
  def upload_to_s3_without_file(s3_bucket:, s3_path:, content:, compress: true)
    Dir.mktmpdir do |dir|
      local_path = File.join(dir, 'local')
      if compress
        Zlib::GzipWriter.open(local_path) { |gz| gz.write content }
      else
        File.open(local_path, 'w') { |f| f.write(content) }
      end

      upload_to_s3(s3_bucket: s3_bucket, s3_path: s3_path, local_path: local_path)
    end
  end

  private

  attr_reader :files

  def generate_file_key(s3_bucket, s3_path)
    "#{s3_bucket}::#{s3_path}"
  end
end