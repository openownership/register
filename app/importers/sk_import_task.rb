class SkImportTask
  def initialize(records, retrieved_at)
    @records = records
    @retrieved_at = retrieved_at
  end

  def call
    importer = SkImporter.new
    importer.source_url = 'https://rpvs.gov.sk/'
    importer.source_name = 'Slovakia Public Sector Partners Register (Register partnerov verejného sektora)'
    importer.document_id = 'Slovakia PSP Register'
    importer.retrieved_at = @retrieved_at
    importer.process_records @records
  end
end
