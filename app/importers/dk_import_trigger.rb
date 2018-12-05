class DkImportTrigger
  def call(chunk_size)
    client = DkClient.new(
      Rails.application.config.dk_cvr.username,
      Rails.application.config.dk_cvr.password,
    )
    retreived_at = Time.zone.now.to_s
    client.all_records.each_slice(chunk_size) do |records|
      # records is an array of hashes, but our ChunkHelper works with
      # arrays of strings
      strings = records.map(&:to_json)
      chunk = ChunkHelper.to_chunk strings
      DkChunkImportWorker.perform_async(chunk, retreived_at)
    end
  end
end
