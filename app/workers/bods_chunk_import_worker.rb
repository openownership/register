require 'zlib'
require 'base64'

class BodsChunkImportWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(chunk, retrieved_at_s, schemes)
    lines = ChunkHelper.from_chunk chunk
    records = lines.map { |l| Oj.load(l, mode: :rails) }
    retrieved_at = Time.zone.parse(retrieved_at_s)

    BodsImportTask.new(records, retrieved_at, schemes).call
  end
end
