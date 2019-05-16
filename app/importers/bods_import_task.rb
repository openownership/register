class BodsImportTask
  def initialize(records, retrieved_at)
    @records = records
    @retrieved_at = retrieved_at
  end

  def call
    extractor = BodsCompanyNumberExtractor.new('GB-COH')
    importer = BodsImporter.new(company_number_extractor: extractor)
    importer.source_url = 'http://example.com'
    importer.source_name = 'BODS Example Data Import'
    importer.document_id = 'BODS'
    importer.retrieved_at = @retrieved_at

    importer.process_records @records
  end
end
