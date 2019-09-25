require 'rails_helper'

RSpec.describe BodsExportUploader do
  include BodsExportHelpers

  let(:export) { create(:bods_export) }
  let(:bucket) { ENV['BODS_EXPORT_S3_BUCKET_NAME'] }
  let(:mapper) { BodsMapper.instance }

  let(:existing_relationship) { create(:relationship) }
  let(:existing_statements) { BodsSerializer.new([existing_relationship], mapper).statements.flatten }
  let(:existing_statement_ids) { existing_statements.map { |s| s[:statementID] } }

  let(:new_relationship) { create(:relationship) }
  let(:new_statements) { BodsSerializer.new([new_relationship], mapper).statements.flatten }
  let(:new_statement_ids) { new_statements.map { |s| s[:statementID] } }

  def expect_s3_object(path)
    s3 = instance_double(Aws::S3::Object)
    expect(Aws::S3::Object).to receive(:new).with(bucket, path).and_return(s3)
    s3
  end

  def expect_s3_download(remote:, local:, contents:)
    s3 = expect_s3_object(remote)
    expect(s3).to receive(:download_file).with(local) do
      Zlib::GzipWriter.open(local) { |gz| gz.write contents }
    end
  end

  def expect_s3_upload(remote:, local:)
    s3 = expect_s3_object(remote)
    expect(s3).to receive(:upload_file).with(local)
  end

  def expect_s3_copy(from:, to:)
    s3_from = expect_s3_object(from)
    s3_to = expect_s3_object(to)
    expect(s3_from).to receive(:copy_to).with(s3_to)
  end

  def create_statement_files(statements)
    statements.each do |statement|
      file = export.statement_filename(statement[:statementID])
      File.open(file, 'w') { |f| f.puts Oj.dump(statement, mode: :rails) }
    end
  end

  let(:redis) { Redis.new }

  before do
    redis.rpush(export.redis_statements_list, new_statement_ids)
  end

  after(:each) do
    redis.flushdb
    redis.close
  end

  it 'concatenates the new statements to the rolling file' do
    with_temp_output_dir(export) do |dir|
      create_statement_files(new_statements)

      expect_s3_download(
        remote: 'public/exports/statements.latest.jsonl.gz',
        local: File.join(dir, 'statements.latest.jsonl.gz'),
        contents: existing_statements.map { |s| Oj.dump(s, mode: :rails) }.join("\n") + "\n",
      )
      expect_s3_download(
        remote: 'public/exports/statement-ids.latest.txt.gz',
        local: File.join(dir, 'statement-ids.latest.txt.gz'),
        contents: existing_statement_ids.join("\n") + "\n",
      )

      expect_s3_upload(
        remote: "public/exports/statements.latest.jsonl.gz",
        local: File.join(dir, 'statements.latest.jsonl.gz'),
      )
      expect_s3_upload(
        remote: "public/exports/statement-ids.latest.txt.gz",
        local: File.join(dir, 'statement-ids.latest.txt.gz'),
      )

      expect_s3_copy(
        from: "public/exports/statements.latest.jsonl.gz",
        to: "public/exports/statements.#{export.created_at.iso8601}.jsonl.gz",
      )
      expect_s3_copy(
        from: "public/exports/statement-ids.latest.txt.gz",
        to: "public/exports/statement-ids.#{export.created_at.iso8601}.txt.gz",
      )

      BodsExportUploader.new(export.id).call

      statements_json = Zlib::GzipReader.open(
        File.join(dir, 'statements.latest.jsonl.gz'),
        &:readlines
      ).map(&:chomp).compact
      statements = statements_json.map { |s| Oj.load(s, mode: :rails, symbol_keys: true) }
      expect(statements).to eq(existing_statements + new_statements)

      statement_ids = Zlib::GzipReader.open(
        File.join(dir, 'statement-ids.latest.txt.gz'),
        &:readlines
      ).map(&:chomp).compact
      expect(statement_ids).to eq(existing_statement_ids + new_statement_ids)
    end
  end

  it 'raises an error if a shell command fails' do
    with_temp_output_dir(export) do |dir|
      # Stub the downloads, but don't create the statement files, meaning the
      # concatenation will fail
      expect_s3_download(
        remote: 'public/exports/statements.latest.jsonl.gz',
        local: File.join(dir, 'statements.latest.jsonl.gz'),
        contents: existing_statements.map { |s| Oj.dump(s, mode: :rails) }.join("\n") + "\n",
      )
      expect_s3_download(
        remote: 'public/exports/statement-ids.latest.txt.gz',
        local: File.join(dir, 'statement-ids.latest.txt.gz'),
        contents: existing_statement_ids.join("\n") + "\n",
      )
      expect do
        BodsExportUploader.new(export.id).call
      end.to raise_error(RuntimeError)
    end
  end

  it 'completes the export' do
    with_temp_output_dir(export) do |dir|
      create_statement_files(new_statements)

      expect_s3_download(
        remote: 'public/exports/statements.latest.jsonl.gz',
        local: File.join(dir, 'statements.latest.jsonl.gz'),
        contents: existing_statements.map { |s| Oj.dump(s, mode: :rails) }.join("\n") + "\n",
      )
      expect_s3_download(
        remote: 'public/exports/statement-ids.latest.txt.gz',
        local: File.join(dir, 'statement-ids.latest.txt.gz'),
        contents: existing_statement_ids.join("\n") + "\n",
      )

      expect_s3_upload(
        remote: "public/exports/statements.latest.jsonl.gz",
        local: File.join(dir, 'statements.latest.jsonl.gz'),
      )
      expect_s3_upload(
        remote: "public/exports/statement-ids.latest.txt.gz",
        local: File.join(dir, 'statement-ids.latest.txt.gz'),
      )

      expect_s3_copy(
        from: "public/exports/statements.latest.jsonl.gz",
        to: "public/exports/statements.#{export.created_at.iso8601}.jsonl.gz",
      )
      expect_s3_copy(
        from: "public/exports/statement-ids.latest.txt.gz",
        to: "public/exports/statement-ids.#{export.created_at.iso8601}.txt.gz",
      )

      BodsExportUploader.new(export.id).call

      expect(export.reload.completed_at).to be_within(1.second).of(Time.zone.now)
    end
  end
end
