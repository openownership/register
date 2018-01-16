require 'zip'

namespace :psc do
  desc 'Import PSC data from source (URL or path)'
  task :import, [:source, :retrieved_at] => [:environment] do |_task, args|
    Rails.application.eager_load!

    importer = PscImporter.new
    importer.source_url = 'http://download.companieshouse.gov.uk/en_pscdata.html'
    importer.source_name = 'UK PSC Register'
    importer.document_id = 'GB PSC Snapshot'
    importer.retrieved_at = Time.zone.parse(args.retrieved_at)

    open(args.source) do |file|
      case File.extname(args.source)
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
