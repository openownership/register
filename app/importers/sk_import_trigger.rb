require 'open-uri'

class SkImportTrigger
  def call(data_source, chunk_size)
    import = Import.create! data_source: data_source
    client = SkClient.new
    retreived_at = Time.zone.now.to_s

    client.all_records.lazy.each_slice(chunk_size) do |records|
      # There's nothing in the SK data which can function as an etag
      raw_records = records.map { |r| { raw_data: Oj.dump(r, mode: :rails), etag: nil } }
      result = RawDataRecord.bulk_upsert_for_import(raw_records, import)
      next if result.upserted_ids.empty?

      record_ids = result.upserted_ids.map(&:to_s)
      RawDataRecordsImportWorker.perform_async(record_ids, retreived_at, import.id.to_s, 'SkImporter')
    end
  end
end
