require 'optparse'
require 'open-uri'

namespace :ua do
  desc 'Import Ukraine data from source (URL or path)'
  task :import, %i[source retrieved_at] => [:environment] do |_task, args|
    Rails.application.eager_load!

    importer = UaImporter.new
    importer.source_url = 'https://data.gov.ua/dataset/1c7f3815-3259-45e0-bdf1-64dca07ddc10'
    importer.source_name = 'Ukraine Consolidated State Registry (Edinyy Derzhavnyj Reestr [EDR])'
    importer.document_id = 'Ukraine EDR'
    importer.retrieved_at = Time.zone.parse(args.retrieved_at)

    open(args.source) do |file|
      file = Zlib::GzipReader.new(file) if File.extname(args.source) == ".gz"

      importer.parse(file)
    end
  end
end
