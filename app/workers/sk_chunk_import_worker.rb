require 'zlib'
require 'base64'
require 'json'

class SkChunkImportWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(chunk, retrieved_at_s)
    lines = ChunkHelper.from_chunk chunk
    records = lines.map { |s| JSON.parse s }
    retrieved_at = Time.zone.parse(retrieved_at_s)

    SkImportTask.new(records, retrieved_at).call
  end
end
