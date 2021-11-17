class BodsImportTrigger
  def initialize(download_url, schemes, chunk_size, jsonl: false)
    @download_url = download_url
    @schemes = schemes
    @chunk_size = chunk_size
    @jsonl = jsonl
  end

  def call
    retrieved_at = Time.zone.now.to_s
    records.each_slice(@chunk_size) do |record_strings|
      chunk = ChunkHelper.to_chunk record_strings
      BodsChunkImportWorker.perform_async(chunk, retrieved_at, @schemes)
    end
  end

  private

  def records
    return jsonl_records if @jsonl

    Oj.load(URI.open(@download_url).read, mode: :rails).map { |r| Oj.dump(r, mode: :rails) }
  end

  def jsonl_records
    Enumerator.new do |yielder|
      URI.open(@download_url) do |f|
        f.each { |line| yielder << line.chomp }
      end
    end
  end
end
