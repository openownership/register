class DkImportTrigger
  def call(data_source, chunk_size)
    import = Import.create! data_source: data_source
    client = DkClient.new(
      Rails.application.config.dk_cvr.username,
      Rails.application.config.dk_cvr.password,
    )
    retreived_at = Time.zone.now.to_s

    client.all_records.lazy.each_slice(chunk_size) do |records|
      raw_records = records.map do |record|
        {
          raw_data: Oj.dump(record, mode: :rails),
          etag: etag(record),
        }
      end
      record_ids = RawDataRecord.bulk_save_for_import(raw_records, import).map(&:to_s)
      next if record_ids.empty?
      DkChunkImportWorker.perform_async(record_ids, retreived_at, import.id.to_s)
    end
  end

  private

  def etag(record)
    return if record['sidstOpdateret'].blank? || record['enhedsNummer'].blank?
    RawDataRecord.etag("#{record['sidstOpdateret']}_#{record['enhedsNummer']}")
  end
end
