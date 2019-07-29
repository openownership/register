require 'open-uri'

class SkImportTrigger
  def call(data_source, chunk_size)
    import = Import.create! data_source: data_source
    client = SkClient.new
    retreived_at = Time.zone.now.to_s

    client.all_records.lazy.each_slice(chunk_size) do |records|
      # There's nothing in the SK data which can function as an etag
      raw_records = records.map { |r| { data: r, etag: nil } }
      record_ids = RawDataRecord.bulk_save_for_import(raw_records, import).map(&:to_s)
      next if record_ids.empty?
      SkChunkImportWorker.perform_async(record_ids, retreived_at, import.id.to_s)
    end
  end
end
