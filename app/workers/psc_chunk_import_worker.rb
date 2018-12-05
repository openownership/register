require 'zlib'
require 'base64'

class PscChunkImportWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(chunk, retrieved_at)
    lines = ChunkHelper.from_chunk chunk
    records = lines.map do |line|
      JSON.parse(line, symbolize_names: true, object_class: OpenStruct)
    end

    PscImportTask.new(records, retrieved_at).call
  end
end
