require 'zip'
require 'open-uri'

class PscImportTask
  def initialize(source, retrieved_at)
    @source = source
    @retrieved_at = retrieved_at
  end

  def call
    importer = PscImporter.new
    importer.source_url = 'http://download.companieshouse.gov.uk/en_pscdata.html'
    importer.source_name = 'UK PSC Register'
    importer.document_id = 'GB PSC Snapshot'
    importer.retrieved_at = Time.zone.parse(@retrieved_at)

    open(@source) do |file|
      case File.extname(@source)
      when ".gz"
        file = Zlib::GzipReader.new(file)
      when ".zip"
        zip = Zip::File.new(file)
        raise if zip.count > 1

        file = zip.first.get_input_stream
      end

      importer.parse(file)
    end
  end
end
