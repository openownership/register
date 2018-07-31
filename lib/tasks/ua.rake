require 'optparse'
require 'open-uri'

namespace :ua do
  desc 'Import Ukraine data from source (URL or path)'
  task :import, %i[source retrieved_at] => [:environment] do |_task, args|
    Rails.application.eager_load!

    importer = UaImporter.new
    importer.source_url = 'http://data.gov.ua/passport/73cfe78e-89ef-4f06-b3ab-eb5f16aea237'
    importer.source_name = 'Ukraine Consolidated State Registry (Edinyy Derzhavnyj Reestr [EDR])'
    importer.document_id = 'Ukraine EDR'
    importer.retrieved_at = Time.zone.parse(args.retrieved_at)

    open(args.source) do |file|
      file = Zlib::GzipReader.new(file) if File.extname(args.source) == ".gz"

      importer.parse(file)
    end
  end
end
