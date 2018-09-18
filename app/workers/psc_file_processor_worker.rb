require 'open-uri'
require 'zip'
require 'zlib'
require 'base64'

class PscFileProcessorWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(source_url, chunk_size)
    retrieved_at = Time.zone.now.to_s

    with_file(source_url) do |file|
      with_chunks(file, chunk_size) do |chunk|
        PscChunkImportWorker.perform_async(chunk, retrieved_at)
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
        zip = Zip::File.new(file)
        raise if zip.count > 1

        file = zip.first.get_input_stream
      end

      yield file
    end
  end

  def with_chunks(file, chunk_size)
    file.lazy.each_slice(chunk_size) do |lines|
      chunk = ChunkHelper.to_chunk lines
      yield chunk
    end
  end
end
