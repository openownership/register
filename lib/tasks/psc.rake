namespace :psc do
  desc 'Import PSC data from source (URL or path)'
  task :import, [:source] => [:environment] do |_task, args|
    Rails.application.eager_load!

    importer = PscImporter.new

    open(args.source) do |file|
      importer.parse(file, document_id: 'GB PSC Snapshot')
    end
  end
end
