namespace :dk do
  desc 'Import Denmark CVR data'
  task :import => :environment do
    Rails.application.eager_load!

    importer = DkImporter.new
    importer.source_url = 'https://cvr.dk'
    importer.source_name = 'Denmark Central Business Register (Centrale Virksomhedsregister [CVR])'
    importer.document_id = 'Denmark CVR'
    importer.retrieved_at = Time.zone.now
    importer.import
  end
end
