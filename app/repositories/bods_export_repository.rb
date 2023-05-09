require 'ostruct'

class BodsExportRepository
  def initialize(s3_adapter: nil, s3_bucket: nil, s3_prefix: nil)
    @s3_adapter = s3_adapter || Rails.application.config.s3_adapter
    @s3_bucket = s3_bucket || ENV.fetch('BODS_EXPORT_S3_BUCKET_NAME')
    @s3_prefix = s3_prefix || ENV.fetch('BODS_EXPORT_S3_PREFIX', 'public/exports/')
  end

  def completed_exports(limit: 5)
    list_all[0...limit]
  end

  def most_recent
    list_all.first
  end

  private

  attr_reader :s3_adapter, :s3_bucket, :s3_prefix

  def list_all
    s3_paths = s3_adapter.list_objects(s3_bucket: s3_bucket, s3_prefix: File.join(s3_prefix, 'statements.'))

    s3_paths.sort.reverse.map do |s3_path|
      time = begin
        Time.parse(s3_path.split('.')[1])
      rescue ArgumentError
        next
      end

      OpenStruct.new(created_at: time, s3_path: s3_path)
    end.compact
  end
end
