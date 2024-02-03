# frozen_string_literal: true

require 'ostruct'

class BodsExportRepository
  def initialize(s3_adapter: nil, s3_bucket: nil, s3_prefix: nil)
    @s3_adapter = s3_adapter || Rails.application.config.s3_adapter
    @s3_bucket = s3_bucket || ENV.fetch('BODS_EXPORT_S3_BUCKET_NAME')
    @s3_prefix = s3_prefix || ENV.fetch('BODS_EXPORT_S3_PREFIX', 'exports/')
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
    s3_paths = s3_adapter.list_objects(s3_bucket:, s3_prefix:)

    s3_paths.map do |s3_path|
      matched1 = /ex(?<year>\d{4})(?<month>\d{2})(?<day>\d{2})/.match s3_path
      matched2 = /all\.(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2}).*\.jsonl\.gz/.match s3_path
      matched = matched1 || matched2
      next unless matched

      time = begin
        Time.zone.local(matched[:year], matched[:month], matched[:day])
      rescue ArgumentError
        next
      end

      OpenStruct.new(created_at: time, s3_path:) # rubocop:disable Style/OpenStructUse
    end.compact.sort_by(&:created_at).reverse
  end
end
