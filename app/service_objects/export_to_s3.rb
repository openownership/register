class ExportToS3
  def initialize(export)
    @export = export
  end

  def call
    compress_data = CompressData.new(@export)
    archive = compress_data.call
    UploadFile.from(archive, to: @export.name + '.jsonl.gz')
    archive.unlink
  end
end
