require 'zlib'
require 'base64'
require 'json'

class SkChunkImportWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(record_ids, retrieved_at_s, import_id)
    records = RawDataRecord.find(record_ids)
    records = [records] unless records.is_a? Array
    retrieved_at = Time.zone.parse(retrieved_at_s)
    import = Import.find(import_id)

    importer = SkImporter.new
    importer.import = import
    importer.retrieved_at = retrieved_at
    importer.process_records records
  end
end
