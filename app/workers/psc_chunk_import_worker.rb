require 'zlib'
require 'base64'

class PscChunkImportWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(chunk, retrieved_at_s, import_id)
    lines = ChunkHelper.from_chunk chunk
    records = lines.map { |line| JSON.parse line }
    retrieved_at = Time.zone.parse(retrieved_at_s)
    import = Import.find import_id

    importer = PscImporter.new
    importer.import = import
    importer.retrieved_at = retrieved_at
    importer.process_records records
  end
end
