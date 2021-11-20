class BodsExportUploader
  include SystemCallHelper
  attr_accessor :export_id

  def initialize(export_id, incremental: false)
    @export = BodsExport.find(export_id)
    @incremental = incremental

    @redis = Redis.new

    @bucket = ENV['BODS_EXPORT_S3_BUCKET_NAME']
    @s3_folder = 'public/exports'
    @s3_adapter = Rails.application.config.s3_adapter.new(
      region: 'eu-west-1',
      access_key_id: ENV['BODS_EXPORT_AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['BODS_EXPORT_AWS_SECRET_ACCESS_KEY'],
    )

    @local_folder = @export.output_folder

    @all_statements = 'statements.latest.jsonl.gz'
    @export_statements = "statements.#{@export.created_at.iso8601}.jsonl.gz"

    @all_statement_ids = 'statement-ids.latest.txt.gz'
    @export_statement_ids = "statement-ids.#{@export.created_at.iso8601}.txt.gz"

    @appended_statements_set = "#{BodsExport::REDIS_ALL_STATEMENTS_SET}:#{export_id}:appended"
  end

  def call
    if @incremental
      download_from_s3(@all_statements)
      download_from_s3(@all_statement_ids)
    end
    append_new_statements
    upload_to_s3(@all_statements)
    upload_to_s3(@all_statement_ids)
    copy_file_in_s3(@all_statements, @export_statements)
    copy_file_in_s3(@all_statement_ids, @export_statement_ids)
    complete_export
  ensure
    @redis.del @appended_statements_set
  end

  def download_from_s3(filename)
    local_path = File.join(@local_folder, filename)
    s3_path = "#{@s3_folder}/#{filename}"
    s3_adapter.download_from_s3(s3_bucket: @bucket, s3_path: s3_path, local_path: local_path)
  rescue Rails.application.config.s3_adapter::Errors::NoSuchKey
    Rails.logger.warn("[#{self.class.name}] File #{s3_path} does not existing in #{@bucket}, skipping")
  end

  def append_new_statements
    statements_file = File.join(@local_folder, @all_statements)
    ids_file = File.join(@local_folder, @all_statement_ids)

    system_or_raise_exception("[ -f #{statements_file} ] && gunzip #{statements_file} || exit 0")
    system_or_raise_exception("[ -f #{ids_file} ] && gunzip #{ids_file} || exit 0")

    statements_file.chomp!('.gz')
    ids_file.chomp!('.gz')

    num_statement_ids = @redis.llen @export.redis_statements_list

    (0..num_statement_ids - 1).each do |index|
      statement_id = @redis.lindex @export.redis_statements_list, index
      next if seen_statement_id?(statement_id)

      statement_file = @export.statement_filename(statement_id)
      system_or_raise_exception("cat #{statement_file} >> #{statements_file}")
      system_or_raise_exception("echo #{statement_id} >> #{ids_file}")
      @redis.sadd(@appended_statements_set, statement_id)
    end

    system_or_raise_exception("gzip #{statements_file}")
    system_or_raise_exception("gzip #{ids_file}")
  end

  def upload_to_s3(filename)
    local_path = File.join(@local_folder, filename)
    s3_adapter.upload_to_s3(s3_bucket: @bucket, s3_path: "#{@s3_folder}/#{filename}", local_path: local_path)
  end

  def copy_file_in_s3(from, to)
    s3_adapter.copy_file_in_s3(s3_bucket: @bucket, s3_path_from: "#{@s3_folder}/#{from}", s3_path_to: "#{@s3_folder}/#{to}")
  end

  def complete_export
    @export.touch(:completed_at)
  end

  private

  attr_reader :s3_adapter

  def seen_statement_id?(statement_id)
    @redis.sismember(@appended_statements_set, statement_id)
  end
end
