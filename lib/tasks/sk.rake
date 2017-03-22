namespace :sk do
  desc 'Import Slovakia data from rpvs.gov.sk'
  task :import => [:environment] do
    Rails.application.eager_load!

    importer = SkImporter.new
    importer.source_url = 'https://rpvs.gov.sk/'
    importer.source_name = 'Slovakia Public Sector Partners Register (Register partnerov verejného sektora)'
    importer.document_id = 'Slovakia PSP Register'
    importer.retrieved_at = Time.zone.now
    importer.import
  end
end
