class BodsImportTrigger
  DOWNLOAD_URL = 'https://raw.githubusercontent.com/openownership/data-standard/da1f653e7f6ecd2af659fb63f2f082852be7597d/examples/1-single-direct.json'.freeze

  def call
    retreived_at = Time.zone.now.to_s
    records = JSON.parse(open(DOWNLOAD_URL).read)
    # records is an array of hashes, but our ChunkHelper works with
    # arrays of strings
    strings = records.map(&:to_json)
    chunk = ChunkHelper.to_chunk strings
    BodsChunkImportWorker.perform_async(chunk, retreived_at)
  end
end
