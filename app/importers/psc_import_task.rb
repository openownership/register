class PscImportTask
  def initialize(records, retrieved_at)
    @records = records
    @retrieved_at = retrieved_at
  end

  def call
    importer = PscImporter.new
    importer.source_url = 'http://download.companieshouse.gov.uk/en_pscdata.html'
    importer.source_name = 'UK PSC Register'
    importer.document_id = 'GB PSC Snapshot'
    importer.retrieved_at = @retrieved_at
    importer.process_records @records
  end
end
