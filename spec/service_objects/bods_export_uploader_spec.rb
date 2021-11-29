require 'rails_helper'

RSpec.describe BodsExportUploader do
  include BodsExportHelpers

  let(:export) { create(:bods_export) }
  let(:bucket) { ENV['BODS_EXPORT_S3_BUCKET_NAME'] }
  let(:mapper) { BodsMapper.instance }

  let(:existing_relationship) { create(:relationship) }
  let(:existing_statements) { BodsSerializer.new([existing_relationship], mapper).statements.flatten }
  let(:existing_statements_dump) do
    existing_statements.map { |s| Oj.dump(s, mode: :rails) }.join("\n") + "\n" # rubocop:disable Style/StringConcatenation
  end
  let(:existing_statement_ids) { existing_statements.pluck(:statementID) }
  let(:existing_statement_ids_dump) { "#{existing_statement_ids.join("\n")}\n" }

  let(:new_relationship) { create(:relationship) }
  let(:new_statements) { BodsSerializer.new([new_relationship], mapper).statements.flatten }
  let(:new_statement_ids) { new_statements.pluck(:statementID) }

  let(:s3_adapter) { Rails.application.config.s3_adapter.new }

  before do
    expect(Rails.application.config.s3_adapter).to receive(:new).with(
      hash_including(:access_key_id, :secret_access_key),
    ).and_return(s3_adapter)
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

      s3_adapter.upload_to_s3_without_file(
        s3_bucket: bucket,
        s3_path: 'public/exports/statements.latest.jsonl.gz',
        content: existing_statements_dump,
      )
      s3_adapter.upload_to_s3_without_file(
        s3_bucket: bucket,
        s3_path: 'public/exports/statement-ids.latest.txt.gz',
        content: existing_statement_ids_dump,
      )

      expect(s3_adapter).to receive(:download_from_s3).with(
        s3_bucket: bucket,
        s3_path: 'public/exports/statements.latest.jsonl.gz',
        local_path: File.join(dir, 'statements.latest.jsonl.gz'),
      ).and_call_original
      expect(s3_adapter).to receive(:download_from_s3).with(
        s3_bucket: bucket,
        s3_path: 'public/exports/statement-ids.latest.txt.gz',
        local_path: File.join(dir, 'statement-ids.latest.txt.gz'),
      ).and_call_original

      expect(s3_adapter).to receive(:upload_to_s3).with(
        s3_bucket: bucket,
        s3_path: "public/exports/statements.latest.jsonl.gz",
        local_path: File.join(dir, 'statements.latest.jsonl.gz'),
      ).and_call_original
      expect(s3_adapter).to receive(:upload_to_s3).with(
        s3_bucket: bucket,
        s3_path: "public/exports/statement-ids.latest.txt.gz",
        local_path: File.join(dir, 'statement-ids.latest.txt.gz'),
      ).and_call_original

      expect(s3_adapter).to receive(:copy_file_in_s3).with(
        s3_bucket: bucket,
        s3_path_from: "public/exports/statements.latest.jsonl.gz",
        s3_path_to: "public/exports/statements.#{export.created_at.iso8601}.jsonl.gz",
      ).and_call_original
      expect(s3_adapter).to receive(:copy_file_in_s3).with(
        s3_bucket: bucket,
        s3_path_from: "public/exports/statement-ids.latest.txt.gz",
        s3_path_to: "public/exports/statement-ids.#{export.created_at.iso8601}.txt.gz",
      ).and_call_original

      BodsExportUploader.new(export.id, incremental: true).call

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

  context 'when there are duplicate statement ids in the list' do
    # Despite our best efforts to de-dupe statement output, because we use
    # multiple independent workers and write their output to a list (not a set),
    # we can end up with duplicate statement ids in that list.
    # Therefore, when we combine the statements into a single file, we keep
    # another Redis set to de-dupe.

    before do
      # Duplicate a statement ID in the ordered list of ids the uploader works
      # through
      redis.rpush(export.redis_statements_list, new_statement_ids.last)
    end

    it "de-dupes them when appending to the rolling file" do
      with_temp_output_dir(export) do |dir|
        create_statement_files(new_statements)

        s3_adapter.upload_to_s3_without_file(
          s3_bucket: bucket,
          s3_path: 'public/exports/statements.latest.jsonl.gz',
          content: existing_statements_dump,
        )
        s3_adapter.upload_to_s3_without_file(
          s3_bucket: bucket,
          s3_path: 'public/exports/statement-ids.latest.txt.gz',
          content: existing_statement_ids_dump,
        )

        expect(s3_adapter).to receive(:download_from_s3).with(
          s3_bucket: bucket,
          s3_path: 'public/exports/statements.latest.jsonl.gz',
          local_path: File.join(dir, 'statements.latest.jsonl.gz'),
        ).and_call_original
        expect(s3_adapter).to receive(:download_from_s3).with(
          s3_bucket: bucket,
          s3_path: 'public/exports/statement-ids.latest.txt.gz',
          local_path: File.join(dir, 'statement-ids.latest.txt.gz'),
        ).and_call_original

        expect(s3_adapter).to receive(:upload_to_s3).with(
          s3_bucket: bucket,
          s3_path: "public/exports/statements.latest.jsonl.gz",
          local_path: File.join(dir, 'statements.latest.jsonl.gz'),
        ).and_call_original
        expect(s3_adapter).to receive(:upload_to_s3).with(
          s3_bucket: bucket,
          s3_path: "public/exports/statement-ids.latest.txt.gz",
          local_path: File.join(dir, 'statement-ids.latest.txt.gz'),
        ).and_call_original

        expect(s3_adapter).to receive(:copy_file_in_s3).with(
          s3_bucket: bucket,
          s3_path_from: "public/exports/statements.latest.jsonl.gz",
          s3_path_to: "public/exports/statements.#{export.created_at.iso8601}.jsonl.gz",
        ).and_call_original
        expect(s3_adapter).to receive(:copy_file_in_s3).with(
          s3_bucket: bucket,
          s3_path_from: "public/exports/statement-ids.latest.txt.gz",
          s3_path_to: "public/exports/statement-ids.#{export.created_at.iso8601}.txt.gz",
        ).and_call_original

        BodsExportUploader.new(export.id, incremental: true).call

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
  end

  it 'raises an error if a shell command fails' do
    with_temp_output_dir(export) do |dir|
      expect(s3_adapter).to receive(:download_from_s3).with(
        s3_bucket: bucket,
        s3_path: 'public/exports/statements.latest.jsonl.gz',
        local_path: File.join(dir, 'statements.latest.jsonl.gz'),
      ).and_call_original
      expect(s3_adapter).to receive(:download_from_s3).with(
        s3_bucket: bucket,
        s3_path: 'public/exports/statement-ids.latest.txt.gz',
        local_path: File.join(dir, 'statement-ids.latest.txt.gz'),
      ).and_call_original
      expect do
        BodsExportUploader.new(export.id, incremental: true).call
      end.to raise_error(RuntimeError)
    end
  end

  it 'completes the export' do
    with_temp_output_dir(export) do |dir|
      create_statement_files(new_statements)

      s3_adapter.upload_to_s3_without_file(
        s3_bucket: bucket,
        s3_path: 'public/exports/statements.latest.jsonl.gz',
        content: existing_statements_dump,
      )
      s3_adapter.upload_to_s3_without_file(
        s3_bucket: bucket,
        s3_path: 'public/exports/statement-ids.latest.txt.gz',
        content: existing_statement_ids_dump,
      )

      expect(s3_adapter).to receive(:download_from_s3).with(
        s3_bucket: bucket,
        s3_path: 'public/exports/statements.latest.jsonl.gz',
        local_path: File.join(dir, 'statements.latest.jsonl.gz'),
      ).and_call_original
      expect(s3_adapter).to receive(:download_from_s3).with(
        s3_bucket: bucket,
        s3_path: 'public/exports/statement-ids.latest.txt.gz',
        local_path: File.join(dir, 'statement-ids.latest.txt.gz'),
      ).and_call_original

      expect(s3_adapter).to receive(:upload_to_s3).with(
        s3_bucket: bucket,
        s3_path: "public/exports/statements.latest.jsonl.gz",
        local_path: File.join(dir, 'statements.latest.jsonl.gz'),
      ).and_call_original
      expect(s3_adapter).to receive(:upload_to_s3).with(
        s3_bucket: bucket,
        s3_path: "public/exports/statement-ids.latest.txt.gz",
        local_path: File.join(dir, 'statement-ids.latest.txt.gz'),
      ).and_call_original

      expect(s3_adapter).to receive(:copy_file_in_s3).with(
        s3_bucket: bucket,
        s3_path_from: "public/exports/statements.latest.jsonl.gz",
        s3_path_to: "public/exports/statements.#{export.created_at.iso8601}.jsonl.gz",
      ).and_call_original
      expect(s3_adapter).to receive(:copy_file_in_s3).with(
        s3_bucket: bucket,
        s3_path_from: "public/exports/statement-ids.latest.txt.gz",
        s3_path_to: "public/exports/statement-ids.#{export.created_at.iso8601}.txt.gz",
      ).and_call_original

      BodsExportUploader.new(export.id, incremental: true).call

      expect(export.reload.completed_at).to be_within(1.second).of(Time.zone.now)
    end
  end
end
