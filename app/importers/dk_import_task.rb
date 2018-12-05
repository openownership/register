class DkImportTask
  def initialize(records, retrieved_at)
    @records = records
    @retrieved_at = retrieved_at
  end

  def call
    importer = DkImporter.new
    importer.source_url = 'https://cvr.dk'
    importer.source_name = 'Denmark Central Business Register (Centrale Virksomhedsregister [CVR])'
    importer.document_id = 'Denmark CVR'
    importer.retrieved_at = Time.zone.parse(@retrieved_at)
    importer.process_records @records
  end
end
