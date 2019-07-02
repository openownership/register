require 'open-uri'
require 'zip'
require 'zlib'
require 'xxhash'

class PscFileProcessorWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(source_url, chunk_size, import_id)
    import = Import.find import_id
    retrieved_at = Time.zone.now.to_s

    with_file(source_url) do |file|
      file.lazy.each_slice(chunk_size) do |lines|
        record_ids = save_raw_data(lines, import).map(&:to_s)
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

  def save_raw_data(lines, import)
    bulk_operations = lines.map do |line|
      data = JSON.parse(line)
      etag = data.dig('data', 'etag').presence || XXhash.xxh64(line).to_s
      {
        update_one: {
          upsert: true,
          filter: { etag: etag },
          update: {
            '$setOnInsert' => { etag: etag, data: data },
            '$addToSet' => { import_ids: import.id },
          },
        },
      }
    end

    RawDataRecord.collection.bulk_write(bulk_operations, ordered: false).upserted_ids
  end
end
