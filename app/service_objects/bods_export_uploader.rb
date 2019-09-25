class BodsExportUploader
  attr_accessor :export_id

  def initialize(export_id)
    @export = BodsExport.find(export_id)

    @redis = Redis.new
    @bucket = ENV['BODS_EXPORT_S3_BUCKET_NAME']

    @s3_folder = 'public/exports'
    @local_folder = @export.output_folder

    @all_statements = 'statements.latest.jsonl.gz'
    @export_statements = "statements.#{@export.created_at.iso8601}.jsonl.gz"

    @all_statement_ids = 'statement-ids.latest.txt.gz'
    @export_statement_ids = "statement-ids.#{@export.created_at.iso8601}.txt.gz"
  end

  def call
    download_from_s3(@all_statements)
    download_from_s3(@all_statement_ids)
    append_new_statements
    upload_to_s3(@all_statements)
    upload_to_s3(@all_statement_ids)
    copy_file_in_s3(@all_statements, @export_statements)
    copy_file_in_s3(@all_statement_ids, @export_statement_ids)
    complete_export
  end

  def download_from_s3(filename)
    local_file = File.join(@local_folder, filename)
    s3 = Aws::S3::Object.new(@bucket, "#{@s3_folder}/#{filename}")
    s3.download_file(local_file)
  rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
    Rails.logger.warn("[#{self.class.name}] File #{@s3_folder}/#{filename} does not existing in #{@bucket}, skipping")
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
      statement_file = @export.statement_filename(statement_id)
      system_or_raise_exception("cat #{statement_file} >> #{statements_file}")
      system_or_raise_exception("echo #{statement_id} >> #{ids_file}")
    end

    system_or_raise_exception("gzip #{statements_file}")
    system_or_raise_exception("gzip #{ids_file}")
  end

  def upload_to_s3(filename)
    s3 = Aws::S3::Object.new(@bucket, "#{@s3_folder}/#{filename}")
    s3.upload_file(File.join(@local_folder, filename))
  end

  def copy_file_in_s3(from, to)
    s3_from = Aws::S3::Object.new(@bucket, "#{@s3_folder}/#{from}")
    s3_to = Aws::S3::Object.new(@bucket, "#{@s3_folder}/#{to}")
    s3_from.copy_to(s3_to)
  end

  def complete_export
    @export.touch(:completed_at)
  end

  def system_or_raise_exception(command)
    stdout, stderr, status = Open3.capture3(command)
    raise "#{command} failed with exit code #{status}. stdout: #{stdout}, stderr: #{stderr}" unless status.exitstatus.zero?
  end
end
