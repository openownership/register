require 'open-uri'

class SkImportTrigger
  def call(chunk_size)
    client = SkClient.new
    retreived_at = Time.zone.now.to_s
    client.all_records.lazy.each_slice(chunk_size) do |records|
      # records is an array of hashes, but our ChunkHelper works with
      # arrays of strings
      strings = records.map(&:to_json)
      chunk = ChunkHelper.to_chunk strings
      SkChunkImportWorker.perform_async(chunk, retreived_at)
    end
  end
end
