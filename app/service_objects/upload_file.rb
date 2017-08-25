class UploadFile
  def self.from(file, to:, s3: Aws::S3::Resource.new)
    new(s3).from(file, to: to)
  end

  def initialize(s3)
    @bucket = s3.bucket(ENV['BUCKETEER_BUCKET_NAME'])
  end

  def from(file, to:)
    @bucket.object(File.join('public', to))
      .upload_file(file.path)
  end
end
