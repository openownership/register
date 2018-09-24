require 'zlib'
require 'base64'

class PscChunkImportWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(chunk, retrieved_at)
    lines = ChunkHelper.from_chunk chunk

    PscImportTask.new(lines, retrieved_at).call
  end
end
