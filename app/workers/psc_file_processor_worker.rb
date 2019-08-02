require 'open-uri'
require 'zip'
require 'zlib'
require 'oj'

class PscFileProcessorWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(source_url, chunk_size, import_id)
    import = Import.find import_id
    retrieved_at = Time.zone.now.to_s

    with_file(source_url) do |file|
      file.lazy.each_slice(chunk_size) do |lines|
        raw_records = lines.map do |line|
          data = Oj.load(line, mode: :rails)
          {
            raw_data: line,
            etag: data.dig('data', 'etag'),
          }
        end
        record_ids = RawDataRecord.bulk_save_for_import(raw_records, import).map(&:to_s)
        next if record_ids.length.zero?
        PscChunkImportWorker.perform_async(record_ids, retrieved_at, import.id.to_s)
      end
    end
  end

  private

  def with_file(source_url)
    open(source_url) do |file|
      case File.extname(source_url)
      when ".gz"
        file = Zlib::GzipReader.new(file)
      when ".zip"
        zip = Zip::File.open_buffer(file)
        raise if zip.count > 1

        file = zip.first.get_input_stream
      end

      yield file
    end
  end
end
