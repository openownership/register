class CompressData
  def self.call(saveable)
    new(saveable).call
  end

  def initialize(saveable)
    @saveable = saveable
  end

  def call
    Tempfile.open([@saveable.name, '.jsonl.gz'], binmode: true) do |file|
      Zlib::GzipWriter.open(file.path) do |gz|
        @saveable.each { |row| gz.write row }
      end
      file
    end
  end
end
