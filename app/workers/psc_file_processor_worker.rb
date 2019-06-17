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
        lines.each.map { |line| save_raw_data(line, import) }
        chunk = ChunkHelper.to_chunk lines
        PscChunkImportWorker.perform_async(chunk, retrieved_at, import.id.to_s)
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

  def save_raw_data(line, import)
    data = JSON.parse(line)
    etag = data.dig('data', 'etag').presence || XXhash.xxh64(line).to_s
    begin
      record = RawDataRecord.find_or_initialize_by(etag: etag)
      record.data = data if record.new_record?
      record.imports << import
      record.save!
    rescue Mongo::Error::OperationFailure => exception
      # Make sure it's a duplicate key error "E11000 duplicate key error collection"
      raise unless exception.message.start_with?('E11000')
      # Make sure it's the etag that is duplicated
      raise unless RawDataRecord.where(etag: etag).exists?
      # Retry, because we should be able to find the record and update it now
      retry
    end
  end
end
