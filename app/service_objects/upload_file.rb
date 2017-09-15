class UploadFile
  def self.from(file, to:, s3: Aws::S3::Resource.new, pr: PullRequestNumber.new)
    new(s3).from(file, to: to, pr: pr)
  end

  def initialize(s3)
    @bucket = s3.bucket(ENV['BUCKETEER_BUCKET_NAME'])
  end

  def from(file, to:, pr:)
    @bucket.object(['public', pr.call, to].compact.join('/'))
      .upload_file(file.path)
  end
end
