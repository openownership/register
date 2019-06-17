require 'zlib'
require 'base64'

class PscChunkImportWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(chunk, retrieved_at_s)
    lines = ChunkHelper.from_chunk chunk
    records = lines.map { |line| JSON.parse line }
    retrieved_at = Time.zone.parse(retrieved_at_s)

    PscImportTask.new(records, retrieved_at).call
  end
end
